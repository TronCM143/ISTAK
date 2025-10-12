// // glass_bottom_bar_liquid_stretch.dart
// import 'dart:math' as math;
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';

// class GlassBottomBar extends StatefulWidget {
//   final int selectedIndex;
//   final Function(int) onItemTapped;

//   const GlassBottomBar({
//     super.key,
//     required this.selectedIndex,
//     required this.onItemTapped,
//   });

//   @override
//   State<GlassBottomBar> createState() => _GlassBottomBarState();
// }

// class _GlassBottomBarState extends State<GlassBottomBar>
//     with TickerProviderStateMixin {
//   final List<IconData> _icons = const [
//     CupertinoIcons.home,
//     CupertinoIcons.book,
//     CupertinoIcons.person,
//     CupertinoIcons.xmark_shield,
//   ];

//   // Layout
//   static const double _barHeight = 72;
//   static const double _itemWidth = 70;
//   static const double _itemGap = 14;
//   static const double _pillHeight = 44;

//   late int _selected;
//   late double _pillCenterX;
//   double? _dragStartX;
//   double? _pillStartX;
//   bool _dragging = false;

//   late final AnimationController _snapCtrl;
//   late Animation<double> _snapAnim;

//   @override
//   void initState() {
//     super.initState();
//     _selected = widget.selectedIndex;
//     _pillCenterX = _centerForIndex(_selected);

//     _snapCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 220),
//     )..addListener(() => setState(() => _pillCenterX = _snapAnim.value));
//   }

//   @override
//   void didUpdateWidget(covariant GlassBottomBar old) {
//     super.didUpdateWidget(old);
//     if (old.selectedIndex != widget.selectedIndex) {
//       _selected = widget.selectedIndex;
//       _animateSnapToIndex(_selected);
//     }
//   }

//   @override
//   void dispose() {
//     _snapCtrl.dispose();
//     super.dispose();
//   }

//   // -------- geometry
//   double _barInnerWidth(int n) => n * _itemWidth + (n - 1) * _itemGap;

//   double _centerForIndex(int i) {
//     final step = _itemWidth + _itemGap;
//     return _itemWidth / 2 + step * i;
//   }

//   int _nearestIndexTo(double cx) {
//     final step = _itemWidth + _itemGap;
//     return ((cx - _itemWidth / 2) / step).round().clamp(0, _icons.length - 1);
//   }

//   double _clampPill(double cx, double maxW) {
//     final left = _itemWidth / 2;
//     final right = maxW - _itemWidth / 2;
//     return cx.clamp(left, right);
//   }

//   void _animateSnapToIndex(int i) {
//     final end = _centerForIndex(i);
//     _snapAnim = Tween<double>(begin: _pillCenterX, end: end)
//         .chain(CurveTween(curve: Curves.easeOutCubic))
//         .animate(_snapCtrl);
//     _snapCtrl
//       ..stop()
//       ..reset()
//       ..forward();
//   }

//   // -------- build
//   @override
//   Widget build(BuildContext context) {
//     return Positioned(
//       left: 16,
//       right: 16,
//       bottom: 16,
//       // Parent breathes with StretchGlass (subtle)
//       child: StretchGlass(
//         stretch: 0.15,
//         interactionScale: 1.01,
//         child: FakeGlass(
//           shape:
//               LiquidRoundedSuperellipse(borderRadius: const Radius.circular(28)),
//           child: SizedBox(
//             height: _barHeight,
//             child: Center(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: LayoutBuilder(builder: (context, constraints) {
//                   final contentW = _barInnerWidth(_icons.length);
//                   final rowW =
//                       math.min(contentW, constraints.maxWidth - 24);
//                   final barMaxW = contentW;

//                   return SizedBox(
//                     width: rowW,
//                     height: double.infinity,
//                     child: Stack(
//                       children: [
//                         // Icons row (tap to jump)
//                         Align(
//                           alignment: Alignment.centerLeft,
//                           child: SizedBox(
//                             width: contentW,
//                             height: double.infinity,
//                             child: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 for (var i = 0; i < _icons.length; i++) ...[
//                                   SizedBox(
//                                     width: _itemWidth,
//                                     height: double.infinity,
//                                     child: InkWell(
//                                       borderRadius: BorderRadius.circular(20),
//                                       onTap: () {
//                                         setState(() => _selected = i);
//                                         _animateSnapToIndex(i);
//                                         widget.onItemTapped(i);
//                                       },
//                                       child: Center(
//                                         child: Icon(
//                                           _icons[i],
//                                           size: (_selected == i) ? 26 : 23,
//                                           color: (_selected == i)
//                                               ? Colors.black87
//                                               : Colors.black87.withOpacity(0.6),
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   if (i != _icons.length - 1)
//                                     const SizedBox(width: _itemGap),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),

//                         // Draggable StretchGlass + LiquidGlass pill
//                         Positioned(
//                           left: _pillCenterX - _itemWidth / 2,
//                           top: (_barHeight - _pillHeight) / 2 - 6,
//                           width: _itemWidth,
//                           height: _pillHeight,
//                           child: StretchGlass(
//                             // noticeable stretch for the active pill
//                             stretch: 0.55,
//                             interactionScale: 1.08,
//                             child: LiquidGlass(
//                               shape: LiquidRoundedSuperellipse(
//                                   borderRadius: const Radius.circular(22)),
//                               settings: const LiquidGlassSettings(
//                                 thickness: 100, // heavy refraction
//                                 glassColor: Color(0x18FFFFFF),
//                                 lightIntensity: 1.25,
//                                 ambientStrength: 0.5,
//                             //    outlineIntensity: 0.35,
//                                 saturation: 1.05,
//                               ),
//                               child: GestureDetector(
//                                 behavior: HitTestBehavior.translucent,
//                                 onPanStart: (d) {
//                                   setState(() {
//                                     _dragging = true;
//                                     _dragStartX = d.localPosition.dx;
//                                     _pillStartX = _pillCenterX;
//                                   });
//                                 },
//                                 onPanUpdate: (d) {
//                                   final dx =
//                                       d.localPosition.dx - (_dragStartX ?? 0);
//                                   setState(() {
//                                     _pillCenterX = _clampPill(
//                                       (_pillStartX ?? _pillCenterX) + dx,
//                                       barMaxW,
//                                     );
//                                   });
//                                 },
//                                 onPanEnd: (_) {
//                                   setState(() => _dragging = false);
//                                   final nearest = _nearestIndexTo(_pillCenterX);
//                                   if (nearest != _selected) {
//                                     setState(() => _selected = nearest);
//                                     widget.onItemTapped(nearest);
//                                   }
//                                   _animateSnapToIndex(nearest);
//                                 },
//                                 child: const SizedBox.expand(),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
