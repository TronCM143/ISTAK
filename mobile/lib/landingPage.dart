import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:mobile/components/utils/animatedBackground.dart';
import 'package:mobile/components/utils/splashPlusLogin.dart';
import 'package:mobile/navBar.dart';
import 'package:mobile/pages/home.dart';
import 'package:mobile/pages/borrowerList.dart';
import 'package:mobile/pages/itemList.dart';
import 'package:mobile/components/utils/quit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavShell extends StatefulWidget {
  const NavShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _accessToken;
  late PageController _controller;
  late int _index;

  final List<Widget> _pages = [HomeContent(), Borrowerlist(), Itemlist()];

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index, keepPage: true);
  }

  Future<void> _loadAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('access_token');
    });
  }

  Future<bool> _handleWillPop() async {
    if (_index > 0) {
      _animateTo(_index - 1);
      return false;
    }
    return true;
  }

  void _animateTo(int i) {
    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onNavItemTapped(int index) {
    if (index == 3) {
      _scaffoldKey.currentState?.openEndDrawer();
    } else {
      _animateTo(index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      // If an endDrawer is open, this will close it.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('refresh_token');
      await prefs.remove('access_token');

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (e, st) {
      debugPrint('Logout failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accessToken == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,

      key: _scaffoldKey,
      backgroundColor: Colors.black,
      endDrawer: SidePanel(access_token: _accessToken!),
      body: Stack(
        children: [
          // Positioned.fill(
          //   //     Image.asset('assets/bgbg.jpg', fit: BoxFit.cover),
          //   child: AbstractWavesBackground(
          //     speed: 0.5, // Controls rotation speed
          //     size: 1500, // Size of the tesseract
          //     positionX: 1, // X position (center of screen)
          //     positionY: 0.5, // Y position (center of screen)
          //   ),
          // ),
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/bgbg.jpg',
          //     fit: BoxFit.cover, // makes it fill the screen
          //     alignment: Alignment.center, // centers the image
          //   ),
          // ),
          AbstractWavesBackground(
            speed: 0.5, // Controls rotation speed
            size: 1500, // Size of the tesseract
            positionX: 1, // X position (center of screen)
            positionY: 0.5, // Y position (center of screen)
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
          WillPopScope(
            onWillPop: _handleWillPop,
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              physics: const BouncingScrollPhysics(),
              children: _pages.map((page) => _KeepAlive(child: page)).toList(),
            ),
          ),

          Positioned(
            top: 0,
            left: 16,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // only as wide as its children
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: "istakLogo",
                      child: Material(
                        type: MaterialType.transparency,
                        child: const Image(
                          image: AssetImage("assets/fullLogo.png"),
                          width: 150,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 220),
                    // Logout button to the right of the logo
                    IconButton(
                      tooltip: 'Logout',
                      splashRadius: 40,
                      onPressed: _logout, // implement below
                      icon: const Icon(
                        CupertinoIcons
                            .square_arrow_right, // or Icons.logout_rounded
                        color: Color.fromARGB(255, 187, 187, 187),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          //   SizedBox(height: 200),
          GlassBottomBar(selectedIndex: _index, onItemTapped: _onNavItemTapped),
        ],
      ),
    );
  }
}

class _AppleGlassCard extends StatelessWidget {
  const _AppleGlassCard({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(4),
    this.onTap,
  });

  final Widget child;
  final double? height;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    final cardCore = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: const SizedBox.expand(),
            ),
          ),
          LiquidGlass(
            settings: LiquidGlassSettings(thickness: 100),
            shape: LiquidRoundedSuperellipse(
              borderRadius: const Radius.circular(24),
            ),
            child: Container(
              height: height ?? 170,
              width: 170,
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? cardCore
        : GestureDetector(onTap: onTap, child: cardCore);
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
