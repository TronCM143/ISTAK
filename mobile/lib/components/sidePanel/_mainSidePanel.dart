import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ✅ for CupertinoIcons
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/sidePanel/borrowerList.dart';
import 'package:mobile/splashPlusLogin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SidePanel extends StatefulWidget {
  final String access_token; // 👈 required string parameter

  const SidePanel({super.key, required this.access_token});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (safeContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Stack(
          children: [
            // tap outside to close
            GestureDetector(
              onTap: () {
                if (Navigator.of(safeContext).canPop()) {
                  Navigator.pop(safeContext);
                }
              },
              child: Container(color: Colors.black.withOpacity(0.01)),
            ),

            // drawer content on the right
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(color: Colors.black),
                child: ListView(
                  padding: const EdgeInsets.only(top: 50, bottom: 20),
                  children: [
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.person_2, // Borrower
                      'Borrower',
                      Colors.lightBlueAccent,
                    ),
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.arrow_2_circlepath, // Transactions
                      'Transactions',
                      Colors.orangeAccent,
                    ),
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.chart_bar, // Reports
                      'Reports',
                      Colors.purpleAccent,
                    ),
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.settings, // Settings
                      'Settings',
                      Colors.tealAccent,
                    ),
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.person_circle, // Profile
                      'Profile',
                      Colors.pinkAccent,
                    ),
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.info, // About
                      'About us',
                      Colors.amberAccent,
                    ),
                    const Divider(color: Colors.white24, thickness: 1),
                    _buildMenuItem(
                      safeContext,
                      CupertinoIcons.square_arrow_right, // Logout
                      'Logout',
                      Colors.redAccent,
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

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    Color iconColor,
  ) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: Colors.white.withOpacity(0.02),
      hoverColor: Colors.white.withOpacity(0.05),
      onTap: () async {
        try {
          if (title == 'Logout') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('refresh_token');
            await prefs.remove('access_token');

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SplashScreen()),
              (route) => false,
            );
          } else if (title == 'Borrower') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => Borrowerlist(access_token: widget.access_token),
              ),

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
