// item_actions_overlay.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:mobile/components/transaction/returning/report/inputData.dart';
import 'package:mobile/components/transaction/returning/RETURN/scanItems.dart';

/// Call this from anywhere to show the two floating glass buttons,
/// with no background behind them.
void showItemActionsOverlay(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false, // <-- keep previous page visible
      barrierColor: Colors.transparent, // <-- no dimming
      pageBuilder: (_, __, ___) => const ItemActionsOverlay(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class ItemActionsOverlay extends StatelessWidget {
  const ItemActionsOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // keep background see-through
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🧊 Full-screen blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withOpacity(0.2), // subtle dim overlay
            ),
          ),

          // 🧱 Foreground content (buttons)
          SafeArea(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🟢 Return Item
                      LiquidGlassButton(
                        width: 200,
                        height: 70,
                        icon: Icons.assignment_return_outlined,
                        label: 'Return Item',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReturnScanScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      // 🔴 Report Lost
                      LiquidGlassButton(
                        width: 200,
                        height: 70,
                        icon: Icons.report_problem_outlined,
                        label: 'Report Lost',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReportInputScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 370),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal “LiquidGlass” style button.
/// If you already have your own LiquidGlass widget, feel free to replace this.
class LiquidGlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;

  const LiquidGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.width = 160,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: GestureDetector(
        onTap: onTap,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
