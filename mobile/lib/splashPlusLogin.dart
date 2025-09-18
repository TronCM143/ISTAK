import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/authentication/page.dart';
import 'package:mobile/components/landing_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _moveLogoUp = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Delay splash screen by 2s then check token
    Future.delayed(const Duration(seconds: 2), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString("refresh_token");

      if (refreshToken != null && refreshToken.isNotEmpty) {
        // ✅ Already logged in → skip AuthPage
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      } else {
        // ❌ No token → show AuthPage
        setState(() {
          _moveLogoUp = true;
        });
        _controller.forward();
      }
    });
  }

  void handleLogin() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF151107)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            top: _moveLogoUp
                ? MediaQuery.of(context).size.height * 0.15
                : MediaQuery.of(context).size.height / 2 - 150,
            left: MediaQuery.of(context).size.width / 2 - 125,
            child: Hero(
              tag: "istakLogo",
              child: Image.asset(
                "assets/fullLogo.png",
                width: 250,
                height: 300,
              ),
            ),
          ),
          SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AuthPage(handleLogin: handleLogin),
            ),
          ),
        ],
      ),
    );
  }
}
