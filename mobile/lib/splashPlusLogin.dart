import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/authentication/page.dart';
import 'package:mobile/components/_landing_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showAuth = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 2));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString("refresh_token");

    if (refreshToken != null && refreshToken.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } else {
      setState(() => _showAuth = true);
    }
  }

  void handleLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Home()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F0F0F)), // dark bg
          // Logo pinned on top
          Positioned(
            top: 170,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showAuth ? 1 : 1, // clearer opacity
              duration: const Duration(milliseconds: 800),
              child: Hero(
                tag: "istakLogo",
                child: SizedBox(
                  width: 90, // <-- change this value
                  height: 80,
                  child: Image.asset(
                    "assets/fullLogo.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // AuthPage sliding from bottom
          if (_showAuth)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: _showAuth ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                child: AuthPage(handleLogin: handleLogin),
              ),
            ),
        ],
      ),
    );
  }
}
