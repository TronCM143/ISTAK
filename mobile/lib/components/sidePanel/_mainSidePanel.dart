import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/sidePanel/inventory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/splashPlusLogin.dart';

class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (safeContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), // ✅ blur background
        child: Stack(
          children: [
            // tap outside to close with better hit detection
            GestureDetector(
              onTap: () {
                if (Navigator.of(safeContext).canPop()) {
                  Navigator.pop(safeContext);
                }
              },
              child: Container(
                color: Colors.black.withOpacity(0.01),
              ), // Slight opacity for hit testing
            ),

            // drawer content on the right
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 32, 28, 16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 40, bottom: 20),
                        children: [
                          _buildMenuItem(safeContext, 'Inventory'),
                          _buildMenuItem(safeContext, 'Borrower'),
                          _buildMenuItem(safeContext, 'Transactions'),
                          _buildMenuItem(safeContext, 'Reports'),
                          _buildMenuItem(safeContext, 'Settings'),
                          _buildMenuItem(safeContext, 'Profile'),
                          _buildMenuItem(safeContext, 'About us'),
                          _buildMenuItem(safeContext, 'Logout'),
                        ],
                      ),
                    ),

                    // ✅ Dancing GIF at the bottom
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Image.asset(
                        "assets/dance.gif",
                        height: 400,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 16,
          color: const Color.fromARGB(255, 212, 186, 148),
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (title == 'Inventory') {
            await prefs.remove('refresh_token');
            await prefs.remove('access_token'); // Clear all tokens
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => Inventory()),
              (route) => false,
            );
          } else if (title == 'Logout') {
            await prefs.remove('refresh_token');
            await prefs.remove('access_token'); // Clear all tokens
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SplashScreen()),
              (route) => false,
            );
          } else {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context); // Close panel
            }
          }
        } catch (e) {
          debugPrint("Error in menu item tap: $e");
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
