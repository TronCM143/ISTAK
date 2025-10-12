import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile/components/utils/animatedBackground.dart';
import 'package:mobile/authentication/page.dart';
import 'package:mobile/pages/home.dart';
import 'package:mobile/landingPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _showAuth = false;
  bool _playedIn = false;
  bool _navigating = false;

  late final AnimationController _lottieCtrl;
  late final AnimationController _backgroundFadeCtrl;
  late final AnimationController _outCtrl;
  late final Animation<double> _outCurve;

  static const int kInSeconds = 3;
  static const int _fadeOutMs = 1000;
  static const int _holdMs = 500; // Reduced hold time before navigation

  @override
  void initState() {
    super.initState();
    _lottieCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: kInSeconds),
    );
    _backgroundFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _fadeOutMs),
    );
    _outCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _fadeOutMs),
    );
    _outCurve = CurvedAnimation(parent: _outCtrl, curve: Curves.easeInOutCubic);
    _initApp();
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    _backgroundFadeCtrl.dispose();
    _outCtrl.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // Start the in-animation immediately
    _playInOnce();
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString("refresh_token");

    if (!mounted) return;

    if (refreshToken != null && refreshToken.isNotEmpty) {
      _playOutAndNavigate(const NavShell());
    } else {
      setState(() => _showAuth = true);
    }
  }

  void handleLogin() {
    if (_navigating) return;
    _playOutAndNavigate(const NavShell());
  }

  void _playInOnce() {
    if (_playedIn) return;
    _playedIn = true;
    _lottieCtrl
      ..reset()
      ..forward(); // Play once for the in-animation
    Future.delayed(const Duration(seconds: kInSeconds), () {
      if (mounted) _lottieCtrl.stop();
    });
  }

  Future<void> _playOutAndNavigate(Widget target) async {
    if (_navigating) return;
    _navigating = true;

    // 1. Fade out the background and auth content
    await Future.wait([_backgroundFadeCtrl.forward(), _outCtrl.forward()]);

    // 2. Brief hold before navigation
    await Future.delayed(const Duration(milliseconds: _holdMs));

    if (!mounted) return;

    // 3. Navigate to Home with a fade-in transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        reverseTransitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (_, __, ___) => target,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Animated background with independent fade
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(
                parent: _backgroundFadeCtrl,
                curve: Curves.easeInOut,
              ),
            ),
            child: const AbstractWavesBackground(
              speed: 0.5, // Controls rotation speed
              size: 1500, // Size of the tesseract
              positionX: 1, // X position (center of screen)
              positionY: 0.5, // Y position (center of screen)
            ),
          ),
          // Backdrop filter for blur effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.transparent),
          ),
          // Auth content with sink/fade effect
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(_outCurve),
            child: AnimatedBuilder(
              animation: _outCurve,
              builder: (context, child) {
                final t = _outCurve.value;
                return Transform(
                  transform: Matrix4.identity()
                    ..translate(
                      0.0,
                      100.0 * t,
                    ) // Increased translation for sink effect
                    ..scale(1.0 - 0.1 * t), // Slightly more scale reduction
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: _showAuth
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.9,
                        width: double.infinity,
                        child: const SafeArea(top: false, child: _AuthHolder()),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Commented-out logo (kept as-is)
          // Positioned(
          //   left: 0,
          //   right: 0,
          //   top: 120,
          //   child: SafeArea(
          //     child: Center(
          //       child: Hero(
          //         tag: "istakLogo",
          //         flightShuttleBuilder: (
          //           BuildContext flightContext,
          //           Animation<double> animation,
          //           HeroFlightDirection flightDirection,
          //           BuildContext fromHeroContext,
          //           BuildContext toHeroContext,
          //         ) {
          //           return AnimatedBuilder(
          //             animation: animation,
          //             builder: (context, child) {
          //               final t = animation.value;
          //               final width = 230 + (150 - 230) * t;
          //               final height = 120 + (80 - 120) * t;
          //               final topOffset = 120 * (1 - t);
          //               print("Hero animation: $t");
          //               return Transform.translate(
          //                 offset: Offset(0, topOffset),
          //                 child: Material(
          //                   type: MaterialType.transparency,
          //                   child: Image.asset(
          //                     "assets/fullLogo.png",
          //                     width: width,
          //                     height: height,
          //                     fit: BoxFit.contain,
          //                   ),
          //                 ),
          //               );
          //             },
          //           );
          //         },
          //         child: Material(
          //           type: MaterialType.transparency,
          //           child: Image.asset(
          //             "assets/fullLogo.png",
          //             width: 230,
          //             height: 120,
          //             fit: BoxFit.contain,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _AuthHolder extends StatelessWidget {
  const _AuthHolder();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SplashScreenState>();
    return AuthPage(handleLogin: state?.handleLogin ?? () {});
  }
}
