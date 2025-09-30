import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/dashboard/_dashboard.dart';
import 'package:mobile/components/dashboard/basicForecasts.dart';
import 'package:mobile/components/dashboard/itemList.dart';
import 'package:mobile/components/dashboard/transactionList.dart';
import 'package:mobile/components/sidePanel/_mainSidePanel.dart';
import 'package:mobile/components/sidePanel/borrowerList.dart';
import 'package:mobile/components/transaction/borrowing/_mainBorrow.dart';
import 'package:mobile/components/transaction/returning.dart';
import 'package:mobile/notifications/notif.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Trigger refresh in TransactionList using GlobalKey
    if (TransactionList.globalKey.currentState != null) {
      await TransactionList.globalKey.currentState!.fetchTransactions();
    }
    Navigator.pop(context); // Close dialog after refresh
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Home constraints: ${MediaQuery.of(context).size}");
    if (_accessToken == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get transactions from TransactionList using GlobalKey
    final transactions =
        TransactionList.globalKey.currentState?.transactions ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromARGB(153, 2, 22, 24),
      endDrawer: SidePanel(access_token: _accessToken!),
      drawerScrimColor: const Color.fromARGB(0, 157, 35, 35),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.transparent,
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
            // Borrow & Return buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  // Left Side (Scanner + Return stacked)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 150,
                          width: 150,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: IconButton(
                                  iconSize: 80,
                                  color: const Color.fromARGB(
                                    255,
                                    241,
                                    241,
                                    241,
                                  ),
                                  icon: const Icon(
                                    CupertinoIcons.qrcode_viewfinder,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const BorrowScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReturnItem(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Return',
                            style: GoogleFonts.ibmPlexMono(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Side: ForecastWidget
                  Expanded(child: ForecastWidget()),
                ],
              ),
            ),
            // Dashboard with pull-to-refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                backgroundColor: Colors.transparent,
                color: Colors.yellow,
                displacement: 40,
                child: const Dashboard(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
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
                          MaterialPageRoute(
                            builder: (_) =>
                                Borrowerlist(access_token: _accessToken!),
                          ),
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
    );
  }
}
