import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/transaction/returning/RETURN/itemModel.dart';
import 'package:mobile/components/transaction/returning/RETURN/summar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'capturePhoto.dart';

const kGreen = Color(0xFF34C759);
const kDarkBg = Color(0xFF0A0A0A);
const kCardBg = Color(0xFF1A1A1A);

class ReturnScanScreen extends StatefulWidget {
  const ReturnScanScreen({super.key});

  @override
  State<ReturnScanScreen> createState() => _ReturnScanScreenState();
}

class _ReturnScanScreenState extends State<ReturnScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );

  final List<ReturnItem> _items = [];
  bool _handling = false;
  bool _torchOn = false;
  String? _photoPath;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture c) async {
    if (_handling) return;
    final code = c.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    _handling = true;
    HapticFeedback.selectionClick();
    await _controller.stop();

    print('Detected code: $code');

    // Parse JSON from QR
    dynamic jsonData;
    try {
      jsonData = json.decode(code);
      if (jsonData is! Map<String, dynamic>) {
        throw Exception('Invalid JSON format');
      }
    } catch (e) {
      print('JSON parse error: $e');
      _showSnack('Invalid QR format: Expected JSON with id and name');
      _handling = false;
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _controller.start();
      return;
    }

    final String? itemId = jsonData['id']?.toString();
    final String? itemName = jsonData['name']?.toString();

    if (itemId == null ||
        itemId.isEmpty ||
        itemName == null ||
        itemName.isEmpty) {
      _showSnack('Invalid QR: Missing id or name');
      _handling = false;
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _controller.start();
      return;
    }

    print('Parsed: ID=$itemId, Name=$itemName');

    // Check if already scanned
    final exist = _items.indexWhere((e) => e.itemId == itemId);
    String? existingCond;
    if (exist >= 0) {
      existingCond = _items[exist].condition;
    }

    final cond = await _showConditionSheet(
      itemId: itemId,
      itemName: itemName,
      existingCond: existingCond,
    );

    if (cond != null) {
      print('Condition selected: $cond for $itemId ($itemName)');
      setState(() {
        if (exist >= 0) {
          _items[exist].condition = cond;
        } else {
          _items.add(
            ReturnItem(itemId: itemId, itemName: itemName, condition: cond),
          );
        }
      });
    } else {
      print('No condition selected for $itemId ($itemName)');
    }

    _handling = false;
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _controller.start();
  }

  Future<String?> _showConditionSheet({
    required String itemId,
    required String itemName,
    String? existingCond,
  }) async {
    String selected = existingCond ?? 'Good';
    const options = ['Good', 'Fair', 'Damaged'];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: kDarkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$itemName',
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    ToggleButtons(
                      isSelected: options.map((o) => selected == o).toList(),
                      onPressed: (index) =>
                          setModalState(() => selected = options[index]),
                      borderRadius: BorderRadius.circular(12),
                      selectedBorderColor: kGreen,
                      selectedColor: Colors.white,
                      fillColor: kGreen.withOpacity(0.1),
                      borderColor: Colors.white24,
                      borderWidth: 1,
                      color: Colors.white, // Unselected text color
                      children: options
                          .map(
                            (o) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                o,
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, selected),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.ibmPlexMono())),
    );
  }

  Future<void> _doneScanning() async {
    if (_items.isEmpty) {
      _showSnack('Scan at least one item.');
      return;
    }
    await _openCapture();
  }

  Future<void> _openCapture() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CapturePhoto(items: List<ReturnItem>.from(_items)),
      ),
    );

    if (!mounted) return;

    if (result is! Map) {
      print('DEBUG: No result map returned from CapturePhoto');
      _showSnack('Scan cancelled.');
      return;
    }

    print('DEBUG: Result from CapturePhoto: $result');
    final photo = result['photoPath'] as String?;
    final raw = (result['items'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e))
        .toList();
    final returnedItems = (raw ?? [])
        .map((m) => ReturnItem.fromJson(m))
        .toList();

    if (photo == null || returnedItems.isEmpty) {
      _showSnack(
        photo == null
            ? 'No photo returned. Please capture again.'
            : 'No items returned. Please rescan.',
      );
      return;
    }

    setState(() {
      _photoPath = photo;
      _items
        ..clear()
        ..addAll(returnedItems);
    });

    print(
      'DEBUG: Items before SummaryScreen: ${_items.map((e) => e.toJson()).toList()}',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          items: List<ReturnItem>.from(_items),
          photoPath: _photoPath!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        elevation: 0,
        title: Text(
          'Return • Scan',
          style: GoogleFonts.ibmPlexMono(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? kGreen : Colors.white70,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          // IconButton(
          //   icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
          //   onPressed: () => _controller.switchCamera(),
          // ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: kDarkBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scanned: ${_items.length} items',
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Simple list preview of scanned items with names
                    if (_items.isNotEmpty)
                      Container(
                        height: 120,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white12),
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.itemName, // Fixed: Use item_name from model
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'ID: ${item.itemId} • ${item.condition}',
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white70,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Expanded(
                        //   child: OutlinedButton.icon(
                        //     label: Text(
                        //       'Done',
                        //       style: GoogleFonts.ibmPlexMono(fontSize: 14),
                        //     ),
                        //     style: OutlinedButton.styleFrom(
                        //       foregroundColor: kGreen,
                        //       side: BorderSide(color: kGreen),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(14),
                        //       ),
                        //       padding: const EdgeInsets.symmetric(vertical: 12),
                        //     ),
                        //     onPressed: _doneScanning,
                        //   ),
                        // ),
                        // const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                            ),
                            label: Text(
                              'Take Photo',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _items.isEmpty ? null : _openCapture,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
