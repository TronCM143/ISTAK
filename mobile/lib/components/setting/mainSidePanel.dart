// lib/components/side_panel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/splashPlusLogin.dart';

class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.40,
      height: MediaQuery.of(context).size.width * 1.2,
      child: Drawer(
        backgroundColor: const Color.fromARGB(255, 32, 28, 16),
        child: ListView(
          padding: const EdgeInsets.only(
            top: 40,
            bottom: 20,
          ), // <-- add bottom padding
          shrinkWrap: true, // so it wraps content, no extra space
          children: [
            _buildMenuItem(context, 'Inventory'),
            _buildMenuItem(context, 'Borrower'),
            _buildMenuItem(context, 'Transactions'),
            _buildMenuItem(context, 'Reports'),
            _buildMenuItem(context, 'Settings'),
            _buildMenuItem(context, 'Profile'),
            _buildMenuItem(context, 'About us'),
            _buildMenuItem(context, 'Logout'),
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
        if (title == 'Logout') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('refresh_token');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        } else {
          Navigator.pop(context); // Close drawer
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
