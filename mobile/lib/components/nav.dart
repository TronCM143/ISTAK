import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GlassBottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const GlassBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIcon(CupertinoIcons.home, 0),
                _buildIcon(CupertinoIcons.book, 1),
                _buildIcon(CupertinoIcons.person, 2),
                _buildIcon(CupertinoIcons.line_horizontal_3, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, int index) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: isSelected ? 80 : 70, // width > height = oval
        height: isSelected ? 45 : 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    const Color.fromARGB(255, 143, 143, 143).withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          // border: isSelected
          //     ? Border.all(color: Colors.transparent, width: 1.8)
          //     : Border.all(color: Colors.white.withOpacity(0.25), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color.fromARGB(255, 232, 232, 232).withOpacity(0.0)
                  : Colors.black.withOpacity(0.1),
              blurRadius: isSelected
                  ? 20
                  : 2, // Use minimal blur for unselected
              spreadRadius: isSelected ? 1 : 0,
              offset: isSelected ? const Offset(0, 2) : const Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedScale(
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: Icon(
            icon,
            color: isSelected
                ? const Color.fromARGB(255, 255, 255, 255)
                : Colors.white70,
            size: isSelected ? 28 : 24,
          ),
        ),
      ),
    );
  }
}

Widget buildOvalIconButton({
  required IconData icon,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(40), // controls the oval curve
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isSelected ? 15 : 0,
          sigmaY: isSelected ? 15 : 0,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          width: isSelected ? 80 : 70, // ⬅ wider than tall = oval
          height: isSelected ? 45 : 40, // ⬅ makes it pill-like
          decoration: BoxDecoration(
            // ❌ don’t use shape: BoxShape.rectangle
            borderRadius: BorderRadius.circular(40),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: Colors.white.withOpacity(isSelected ? 0.12 : 0.04),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: isSelected ? 28 : 24,
            ),
          ),
        ),
      ),
    ),
  );
}
