import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile/animatedBackground.dart';
import 'package:mobile/components/dashboard/_dashboard.dart';
import 'package:mobile/components/dashboard/basicForecasts.dart';
import 'package:mobile/components/dashboard/itemList.dart';
import 'package:mobile/components/dashboard/transactionList.dart';
import 'package:mobile/components/sidePanel/_mainSidePanel.dart';
import 'package:mobile/components/dashboard/borrowerList.dart';
import 'package:mobile/components/transaction/borrowing/_mainBorrow.dart';
import 'package:mobile/components/transaction/returning/returning.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile/notifications/notif.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadAccessToken();
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
  Widget build(BuildContext context) {
    debugPrint("Home constraints: ${MediaQuery.of(context).size}");
    if (_accessToken == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final transactions =
        TransactionList.globalKey.currentState?.transactions ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white, // Solid white background
      endDrawer: SidePanel(access_token: _accessToken!),
      body: Stack(
        children: [
          /// --- Fullscreen animated background ---
          CloudyBackground(),

          /// --- Foreground UI ---
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  color: const Color.fromARGB(0, 205, 204, 204),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Hero(
                        tag: "istakLogo",
                        child: Image(
                          image: AssetImage("assets/fullLogo.png"),
                          width: 120,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 200),
                      IconButton(
                        icon: const Icon(
                          CupertinoIcons.bell,
                          color: Color.fromARGB(255, 206, 192, 152),
                          size: 28,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => const NotificationScreen(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  child: Row(
                    //crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: Scanner takes 2 parts
                      // SizedBox(
                      //   child: Column(
                      //     children: [
                      //       Center(
                      //         child: SizedBox(
                      //           width: 500, // now respected
                      //           height: 500,
                      //           child: _AppleGlassCard(
                      //             onTap: () {
                      //               Navigator.push(
                      //                 context,
                      //                 MaterialPageRoute(
                      //                   builder: (_) => const BorrowScreen(),
                      //                 ),
                      //               );
                      //             },
                      //             child: const Icon(
                      //               CupertinoIcons.qrcode_viewfinder,
                      //               size: 68,
                      //               color: Colors.white,
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                      //       const SizedBox(height: 12),
                      //       // ... your Return button here ...
                      //     ],
                      //   ),
                      // ),
                      SizedBox(width: 10),
                      Column(
                        children: [
                          SizedBox(
                            child: _AppleGlassCard(
                              padding: const EdgeInsets.all(
                                10,
                              ), // 10px margin on all sides
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BorrowScreen(),
                                  ),
                                );
                              },
                              child: Lottie.asset(
                                'assets/qr.json',
                                width: 120, // adjust to fit your design
                                height: 120,
                                fit: BoxFit.contain,
                                repeat: true, // loop animation
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
                                      Text(
                                        'Return',
                                        style: DefaultTextStyle.of(context)
                                            .style
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Colors.white,
                                              letterSpacing: 0.2,
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

                      // RIGHT: Forecast takes 1 part
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            10,
                          ), // 10px margin on all sides
                          child: ForecastWidget(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dashboard with pull-to-refresh
                // Expanded(
                //   child: RefreshIndicator(
                //     onRefresh: _refreshDashboard,
                //     backgroundColor: Colors.transparent,
                //     color: Colors.yellow,
                //     displacement: 40,
                Expanded(child: Dashboard()),

                //   ),
                // ),
              ],
            ),
          ),

          /// --- Floating Bottom Navigation Bar ---
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent, // Explicitly transparent
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.home),
                        color: Colors.white,
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.book),
                        color: Colors.white,
                        onPressed: () {
                          if (_accessToken != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => Itemlist()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please wait, loading access token...',
                                  style: GoogleFonts.ibmPlexMono(
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.person),
                        color: Colors.white,
                        onPressed: () {
                          if (_accessToken != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => Borrowerlist()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please wait, loading access token...',
                                  style: GoogleFonts.ibmPlexMono(
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.line_horizontal_3),
                        color: Colors.white,
                        onPressed: () {
                          _scaffoldKey.currentState?.openEndDrawer();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          // Frosted blurr
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
              color: Colors.transparent, // No background color
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
