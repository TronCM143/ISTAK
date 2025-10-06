import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile/animatedBackground.dart';
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
  bool _playedIn = false;
  bool _navigating = false;

  // Controls the Lottie timeline
  late final AnimationController _lottieCtrl;

  static const int kInSeconds = 3; // play on enter
  static const int kOutSeconds =
      5; // play before leaving (set 4..6 as you prefer)

  @override
  void initState() {
    super.initState();
    _lottieCtrl = AnimationController(vsync: this);
    _initApp();
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // Give your splash a moment before deciding where to go
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString("refresh_token");

    if (!mounted) return;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      // OUT transition → animate for kOutSeconds, then navigate to Home
      _playOutAndNavigate(const Home());
    } else {
      // Stay on this page (Auth visible). Background remains frozen after IN.
      setState(() => _showAuth = true);
    }
  }

  void handleLogin() {
    if (_navigating) return;
    _playOutAndNavigate(const Home());
  }

  void _playInOnce() {
    if (_playedIn) return;
    _playedIn = true;
    _lottieCtrl
      ..reset()
      ..repeat();
    Future.delayed(const Duration(seconds: kInSeconds), () {
      if (mounted) _lottieCtrl.stop(); // freeze frame
    });
  }

  void _playOutAndNavigate(Widget target) {
    if (_navigating) return;
    _navigating = true;

    // Resume animation for the OUT transition
    _lottieCtrl
      ..reset()
      ..repeat();

    Future.delayed(Duration(seconds: kOutSeconds), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const CloudyBackground(),

          /// --- Logo pinned on top ---
          Positioned(
            top: 170,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 800),
              child: Hero(
                tag: "istakLogo",
                child: SizedBox(
                  width: 100,
                  height: 90,
                  child: Image.asset(
                    "assets/fullLogo.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          /// --- AuthPage properly visible ---
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              width: double.infinity,
              child: SafeArea(
                top: false,
                child: AuthPage(handleLogin: handleLogin),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
