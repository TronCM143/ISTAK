import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/splashPlusLogin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SidePanel extends StatefulWidget {
  final String access_token;

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
            // Tap outside to close
            GestureDetector(
              onTap: () {
                if (Navigator.of(safeContext).canPop()) {
                  Navigator.pop(safeContext);
                }
              },
              child: Container(color: Colors.black.withOpacity(0.01)),
            ),
            // Drawer content on the right
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.45,
                height: MediaQuery.of(context).size.height,
                // decoration: BoxDecoration(
                //   borderRadius: BorderRadius.circular(10),
                //   border: Border.all(
                //     color: Colors.white.withOpacity(0.2),
                //     width: 1.5,
                //   ),
                // ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      children: [
                        _buildMenuItem(
                          safeContext,
                          CupertinoIcons.square_arrow_right,
                          'Logout',
                          Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
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
    return GestureDetector(
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
          }
        } catch (e) {
          debugPrint("Error in menu item tap: $e");
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 850),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
