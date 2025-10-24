import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerDialog extends StatefulWidget {
  final bool allowMultiple;
  final Set<String>? initial;
  final void Function(Set<String>) onItemsScanned;
  final VoidCallback onFinish;

  const QRScannerDialog({
    super.key,
    required this.allowMultiple,
    this.initial,
    required this.onItemsScanned,
    required this.onFinish,
  });

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final Set<String> _ids = <String>{};
  final Map<String, String?> _names = <String, String?>{};
  int _lastHitMs = 0;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();

    if (widget.initial != null) {
      for (final id in widget.initial!) {
        _ids.add(id);
        _names[id] = null; // Name unknown until scanned
      }
      if (widget.initial!.isNotEmpty && mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHitMs < 400) return;
    _lastHitMs = now;

    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      try {
        final obj = json.decode(raw);
        if (obj is Map<String, dynamic>) {
          final id = obj['id']?.toString().trim();
          final name = obj['name'] as String?;

          if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
            if (!widget.allowMultiple) {
              widget.onItemsScanned({id});
              widget.onFinish();
              return;
            }

            if (_ids.add(id)) {
              _names[id] = name;
              if (mounted) setState(() {});
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid QR format: missing id or name'),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid QR format: expected JSON')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to parse QR: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 22,
    );
    final bigValue = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: 30,
      letterSpacing: 0.3,
    );
    final smallValue = theme.textTheme.bodyLarge?.copyWith(
      color: Colors.white70,
      fontSize: 18,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.allowMultiple ? 'Scan QRs' : 'Scan QR',
                      style: titleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Toggle Torch',
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() {
                        _isTorchOn = !_isTorchOn;
                      });
                    },
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? Colors.amber : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  IgnorePointer(child: CustomPaint(painter: _CornersPainter())),
                ],
              ),
            ),
            if (widget.allowMultiple)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.black,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Collected:',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Chip(
                            label: Text(
                              '${_ids.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.blueGrey.shade700,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            onPressed: _ids.isEmpty
                                ? null
                                : () => setState(() {
                                    _ids.clear();
                                    _names.clear();
                                  }),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _ids.isEmpty
                            ? Center(
                                child: Text(
                                  'Point camera at QR codes',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white38,
                                    fontSize: 20,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _ids.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white12),
                                itemBuilder: (_, i) {
                                  final id = _ids.elementAt(i);
                                  final name = _names[id];

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name ?? 'Unknown Item',
                                              style: bigValue,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'ID: $id',
                                              style: smallValue,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove',
                                        onPressed: () => setState(() {
                                          _ids.remove(id);
                                          _names.remove(id);
                                        }),
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_ids.isEmpty) return;
                        widget.onItemsScanned(_ids);
                        widget.onFinish();
                      },
                      child: Text(
                        widget.allowMultiple ? 'Done' : 'Use this ID',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const w = 32.0;
    const pad = 18.0;

    canvas.drawLine(Offset(pad, pad), Offset(pad + w, pad), p);
    canvas.drawLine(Offset(pad, pad), Offset(pad, pad + w), p);
    canvas.drawLine(
      Offset(size.width - pad - w, pad),
      Offset(size.width - pad, pad),
      p,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(size.width - pad, pad + w),
      p,
    );
    canvas.drawLine(
      Offset(pad, size.height - pad - w),
      Offset(pad, size.height - pad),
      p,
    );
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(pad + w, size.height - pad),
      p,
    );
    canvas.drawLine(
      Offset(size.width - pad, size.height - pad - w),
      Offset(size.width - pad, size.height - pad),
      p,
    );
    canvas.drawLine(
      Offset(size.width - pad - w, size.height - pad),
      Offset(size.width - pad, size.height - pad),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
