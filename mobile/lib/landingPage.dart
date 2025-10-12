import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:mobile/components/utils/animatedBackground.dart';
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
          //     'assets/forest.png',
          //     fit: BoxFit.cover, // makes it fill the screen
          //     alignment: Alignment.center, // centers the image
          //   ),
          // ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1),
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
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.transparent,
                child: Center(
                  child: Hero(
                    tag: "istakLogo",
                    child: Material(
                      type: MaterialType.transparency,
                      child: Image(
                        image: AssetImage("assets/fullLogo.png"),
                        width: 150,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GlassBottomBar(selectedIndex: _index, onItemTapped: _onNavItemTapped),
        ],
      ),
    );
  }
}

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
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(
            borderRadius: const Radius.circular(30),
          ),
          settings: LiquidGlassSettings(
            thickness: 200,
            glassColor: const Color.fromARGB(255, 54, 54, 54).withOpacity(0.3),
          ),
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
                _buildIcon(CupertinoIcons.xmark_shield, 3),
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
      child: AnimatedScale(
        scale: isSelected ? 1.7 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(
            borderRadius: const Radius.circular(40),
          ),
          settings: LiquidGlassSettings(thickness: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: isSelected ? 80 : 70,
            height: isSelected ? 45 : 40,
            alignment: Alignment.center,
            // decoration: BoxDecoration(
            //   gradient: isSelected
            //       ? LinearGradient(
            //           colors: [
            //             const Color.fromARGB(255, 62, 62, 62).withOpacity(0.5),
            //             const Color.fromARGB(
            //               255,
            //               122,
            //               122,
            //               122,
            //             ).withOpacity(0.5),
            //           ],
            //           begin: Alignment.topLeft,
            //           end: Alignment.bottomRight,
            //         )
            //       : null,
            //   boxShadow: [
            //     BoxShadow(
            //       color: isSelected
            //           ? const Color.fromARGB(255, 49, 48, 48).withOpacity(0.0)
            //           : Colors.black.withOpacity(0.1),
            //       blurRadius: isSelected ? 20 : 2,
            //       spreadRadius: isSelected ? 1 : 0,
            //       offset: isSelected ? const Offset(0, 2) : const Offset(0, 1),
            //     ),
            //   ],
            // ),
            child: Icon(
              icon,
              color: const Color.fromARGB(255, 254, 254, 254),
              size: isSelected ? 28 : 24,
            ),
          ),
        ),
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
