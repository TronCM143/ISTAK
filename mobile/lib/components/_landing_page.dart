import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile/animatedBackground.dart';
import 'package:mobile/components/dashboard/_dashboard.dart';
import 'package:mobile/components/dashboard/basicForecasts.dart';
import 'package:mobile/components/dashboard/itemList.dart';
import 'package:mobile/components/dashboard/transactionList.dart';
import 'package:mobile/components/nav.dart';
import 'package:mobile/components/sidePanel/_mainSidePanel.dart';
import 'package:mobile/components/dashboard/borrowerList.dart';
import 'package:mobile/components/transaction/borrowing/inputData.dart';
import 'package:mobile/components/transaction/returning/returning.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _accessToken;
  late AnimationController _lottieController;
  // Adjustable QR animation size
  final double qrAnimationSize = 100; // Set to 50x50 or adjust as needed
  // Adjustable top margin for _getBody content
  final double topMargin = 100; // Adjust this to control distance from top
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
    // Initialize Lottie AnimationController with adjustable duration
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 4,
      ), // Adjust this for speed (higher = slower)
    )..repeat(); // Loop the animation
  }

  Future<void> _loadAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('access_token');
    });
  }

  Future<void> _refreshDashboard() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 3),
      ),
    );
    if (TransactionList.globalKey.currentState != null) {
      await TransactionList.globalKey.currentState!.fetchTransactions();
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _lottieController.dispose(); // Dispose the Lottie controller
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    if (index == 3) {
      _scaffoldKey.currentState?.openEndDrawer();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _getBody(int index) {
    switch (index) {
      case 0:
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: topMargin), // Adjustable top margin
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          child: _AppleGlassCard(
                            padding: const EdgeInsets.all(1),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BorrowerInputAndPhoto(),
                                ),
                              );
                            },
                            // child: Center(
                            //   child: Lottie.asset(
                            //     'assets/finalQR.json',
                            //     width: qrAnimationSize,
                            //     height: qrAnimationSize,
                            //     fit: BoxFit.contain,
                            //     controller: _lottieController,
                            //   ),
                            // ),
                            child: Center(
                              child: Icon(
                                Icons
                                    .qr_code_scanner, // 📷 built-in QR scanner icon
                                size:
                                    qrAnimationSize, // reuse your existing size variable
                                color: const Color.fromARGB(
                                  255,
                                  176,
                                  176,
                                  176,
                                ), // you can change to any color
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReturnItem(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Center(
                                        child: Text(
                                          'Return',
                                          style: DefaultTextStyle.of(context)
                                              .style
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: Colors.white,
                                                letterSpacing: 0.2,
                                                decoration: TextDecoration.none,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ForecastWidget(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            //r  Dashboard(),
            SizedBox(height: 560, child: TransactionList()),
          ],
        );
      case 1:
        return Padding(
          padding: EdgeInsets.only(top: topMargin), // Apply same top margin
          child: Itemlist(),
        );
      case 2:
        return Padding(
          padding: EdgeInsets.only(top: topMargin), // Apply same top margin
          child: Borrowerlist(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Home constraints: ${MediaQuery.of(context).size}");
    if (_accessToken == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      endDrawer: SidePanel(access_token: _accessToken!),
      body: Stack(
        children: [
          //ANIMATED BACKGROUND
          //  AbstractWavesBackground(), //animated background
          //STATIS IMAGE BACKGROUND
          Positioned.fill(
            child: Image.asset(
              'assets/bg.jpg',
              fit: BoxFit.cover, // fills the screen
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: SafeArea(
                top:
                    false, // Avoid extra top padding since header is positioned
                child: _getBody(_selectedIndex),
              ),
            ),
          ),

          /// --- Fixed Header ---
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            //bottom: 5,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 1,
                  // horizontal: 16,
                ),
                color: const Color.fromARGB(0, 205, 204, 204),
                child: Center(
                  child: const Hero(
                    tag: "istakLogo",
                    child: Image(
                      image: AssetImage("assets/fullLogo.png"),
                      width: 150,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),

                  //      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                ),
              ),
            ),
          ),

          /// --- Floating Bottom Navigation Bar ---
          GlassBottomBar(
            selectedIndex: _selectedIndex,
            onItemTapped: _onNavItemTapped,
          ),
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
          // Frosted blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: const SizedBox.expand(),
            ),
          ),
          // Glass surface
          Container(
            height: 170,
            width: 170,
            padding: EdgeInsets.all(2),
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
        ],
      ),
    );

    return onTap == null
        ? cardCore
        : GestureDetector(onTap: onTap, child: cardCore);
  }
}
