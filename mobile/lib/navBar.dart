import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class GlassBottomBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const GlassBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<GlassBottomBar> createState() => _GlassBottomBarState();
}

class _GlassBottomBarState extends State<GlassBottomBar>
    with SingleTickerProviderStateMixin {
  static const _barHorzPad = 20.0; // matches Container horizontal padding
  static const _itemCount = 3;

  // static const double bubbleW = 86.0; // width
  // static const double bubbleH = 54.0; // height

  bool _bubbleVisible = false;
  double _bubbleX = 0; // local X within the bar
  double _barWidth = 0; // measured via LayoutBuilder
  late final AnimationController _bubbleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late final Animation<double> _bubbleScale = CurvedAnimation(
    parent: _bubbleCtrl,
    curve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _bubbleCtrl.dispose();
    super.dispose();
  }

  // Clamp X so the bubble stays inside the bar (considering padding).
  double _clampX(double x) {
    final minX = _barHorzPad;
    final maxX = _barWidth - _barHorzPad;
    return x.clamp(minX, maxX);
  }

  int _nearestIndex(double x) {
    final segment = _barWidth / _itemCount;
    int i = (x / segment).floor().clamp(0, _itemCount - 1);
    final mid = (i + 0.5) * segment;
    if (x > mid) i = (i + 1).clamp(0, _itemCount - 1);
    return i;
  }

  IconData _iconFor(int idx) {
    switch (idx) {
      case 0:
        return CupertinoIcons.home;
      case 1:
        return CupertinoIcons.book;
      case 2:
        return CupertinoIcons.person;
      default:
        return CupertinoIcons.arrow_counterclockwise_circle_fill;
    }
  }

  void _showBubble(Offset localPos) {
    setState(() {
      _bubbleVisible = true;
      _bubbleX = _clampX(localPos.dx);
    });
    _bubbleCtrl.forward(from: 0);
  }

  void _updateBubble(Offset localPos) {
    setState(() {
      _bubbleX = _clampX(localPos.dx);
    });
  }

  Future<void> _hideBubbleAndNavigate() async {
    final target = _nearestIndex(_bubbleX);
    widget.onItemTapped(target);
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() => _bubbleVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _barWidth = constraints.maxWidth;

          // Bubble size/position
          const bubbleW = 100.0;
          const bubbleH = 80.0;
          final initialX =
              (widget.selectedIndex + 0.5) * (_barWidth / _itemCount);
          final bubbleCenterX = _bubbleVisible ? _bubbleX : initialX;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Tap creates bubble at finger and releases to navigate
            onTapDown: (d) => _showBubble(d.localPosition),
            onTapUp: (_) => _hideBubbleAndNavigate(),
            onTapCancel: () => _hideBubbleAndNavigate(),
            // Drag to scrub between items
            onPanStart: (d) => _showBubble(d.localPosition),
            onPanUpdate: (d) => _updateBubble(d.localPosition),
            onPanEnd: (_) => _hideBubbleAndNavigate(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ==== Base bar (static glass, fixed layout) ====
                // ClipRRect(
                //   borderRadius: BorderRadius.circular(30),
                //   child: LiquidStretch(
                //     stretch: 0.5,
                //     resistance: 0.08,
                //     interactionScale: 1.05,
                //     // shape: LiquidRoundedSuperellipse(
                //     //   borderRadius: const Radius.circular(30),
                //     // ),
                //     // settings: LiquidGlassSettings(
                //     //   // You can keep 200, but ~80–100 is much smoother
                //     //   thickness: 100,
                //     //   glassColor: const Color.fromARGB(
                //     //     255,
                //     //     54,
                //     //     54,
                //     //     54,
                //     //   ).withOpacity(0.3),
                //     // ),
                //     child:
                LiquidGlass(
                  shape: LiquidRoundedSuperellipse(
                    borderRadius: const Radius.circular(30),
                  ),
                  // keeps blur contained to the glass, not your children
                  glassContainsChild: false,
                  clipBehavior: Clip.hardEdge,
                  restrictThickness: true,
                  // tune thickness to taste; lower is cheaper (since you already have an outer glass)
                  settings: const LiquidGlassSettings(
                    blur: 20,
                    thickness: 20,
                    // optional tint baked into the glass itself; you can remove this if you prefer pure blur
                    glassColor: Color.fromARGB(30, 23, 23, 23), // ~12% white
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withOpacity(
                        0.00,
                      ), // your original tint
                      // border: Border.all(
                      //   color: Colors.white.withOpacity(0.25),
                      //   width: 1.2, // your original stroke
                      // ),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withOpacity(0.25),
                      //     blurRadius: 15,
                      //     offset: const Offset(0, 6),
                      //   ),
                      // ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _barHorzPad,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (var i = 0; i < _itemCount; i++)
                            _iconSlot(_iconFor(i), i),
                        ],
                      ),
                    ),
                  ),
                ),

                // ==== Popup draggable bubble ====
                if (_bubbleVisible)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    left: bubbleCenterX - (bubbleW / 2),
                    top: -bubbleH - (-70), // floats above the bar
                    child: ScaleTransition(
                      scale: _bubbleScale,
                      child: _BubbleGlass(
                        width: bubbleW,
                        height: bubbleH,
                        icon: _iconFor(_nearestIndex(bubbleCenterX)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // One slot inside the bar (static glass, only icon scales when selected)
  Widget _iconSlot(IconData icon, int index) {
    final selected = widget.selectedIndex == index;

    return SizedBox(
      width: 80,
      height: 45,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // const RepaintBoundary(
          //   child: LiquidGlass(
          //     shape: LiquidRoundedSuperellipse(
          //       borderRadius: Radius.circular(40),
          //     ),
          //     settings: LiquidGlassSettings(thickness: 70),
          //     child: SizedBox.expand(),
          //   ),
          // ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: selected ? 0.10 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: Colors.white,
              ),
            ),
          ),
          // Icon-only animation (cheap)
          // AnimatedScale(
          //   scale: selected ? 1.25 : 1.0,
          //   duration: const Duration(milliseconds: 180),
          //   curve: Curves.easeOutBack,
          //   child: const RepaintBoundary(
          //     child: Icon(
          //       CupertinoIcons.circle, // replaced below
          //       size: 26,
          //       color: Color(0xFFFEFEFE),
          //     ),
          //   ),
          // ),
        ],
      ),
    )._withIcon(icon);
  }
}

// Helper: replace placeholder icon cleanly
extension on Widget {
  Widget _withIcon(IconData icon) {
    return Builder(
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            this,
            IgnorePointer(
              ignoring: true,
              child: Icon(icon, size: 26, color: const Color(0xFFFEFEFE)),
            ),
          ],
        );
      },
    );
  }
}

// Popup bubble widget (lightweight glass + inner icon)
class _BubbleGlass extends StatelessWidget {
  const _BubbleGlass({
    required this.width,
    required this.height,
    required this.icon,
  });

  final double width;
  final double height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(
          borderRadius: const Radius.circular(22),
        ),
        settings: const LiquidGlassSettings(thickness: 20),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            // border: Border.all(
            //   color: Colors.white.withOpacity(0.30),
            //   width: 1.0,
            // ),
            color: Colors.white.withOpacity(0.08),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // child: Icon(icon, color: const Color(0xFFFEFEFE), size: 26),
        ),
      ),
    );
  }
}
