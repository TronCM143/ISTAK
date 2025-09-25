import 'package:flutter/material.dart';

class LegendIcon extends StatefulWidget {
  const LegendIcon({super.key});

  @override
  State<LegendIcon> createState() => _LegendIconState();
}

class _LegendIconState extends State<LegendIcon> {
  bool _showLegend = false;

  void _onTap() {
    setState(() {
      _showLegend = !_showLegend; // toggle on tap
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The Question Mark Icon
        GestureDetector(
          onTap: _onTap,
          child: Container(
            padding: const EdgeInsets.all(5),
            child: const Icon(
              Icons.question_mark,
              size: 20,
              color: Color.fromARGB(255, 68, 68, 68),
            ),
          ),
        ),

        // Floating Legend
        if (_showLegend)
          Positioned(
            right: -90, // adjust this value to shift position
            top: 40, // show below the icon
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black, // solid black background
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _LegendItem(color: Colors.green, label: "Available"),
                    SizedBox(height: 8),
                    _LegendItem(color: Colors.yellow, label: "Borrowed"),
                    SizedBox(height: 8),
                    _LegendItem(color: Colors.red, label: "Overdue"),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
