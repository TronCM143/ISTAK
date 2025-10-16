import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile/components/transaction/borrowing/processData.dart';

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
  int _lastHitMs = 0;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _ids.addAll(widget.initial!);
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

      final id = _extractItemId(raw);
      if (id == null || id.isEmpty) continue;

      if (!widget.allowMultiple) {
        widget.onItemsScanned({id});
        widget.onFinish();
        return;
      }

      if (_ids.add(id)) {
        if (mounted) setState(() {});
      }
    }
  }

  String? _extractItemId(String raw) {
    try {
      final obj = json.decode(raw);
      if (obj is Map) {
        final v = obj['id'] ?? obj['item_id'] ?? obj['itemId'];
        if (v != null) return v.toString().trim();
      }
    } catch (_) {}

    final uri = Uri.tryParse(raw);
    if (uri != null && (uri.hasQuery || uri.query.isNotEmpty)) {
      final v =
          uri.queryParameters['id'] ??
          uri.queryParameters['item_id'] ??
          uri.queryParameters['itemId'];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      widget.allowMultiple ? 'Scan QR' : 'Scan QRs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
                            'Collected: ',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white70,
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
                                : () => setState(() => _ids.clear()),
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white38,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _ids.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white12),
                                itemBuilder: (_, i) {
                                  final id = _ids.elementAt(i);
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          id,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove',
                                        onPressed: () =>
                                            setState(() => _ids.remove(id)),
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
