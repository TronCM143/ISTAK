import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/dashboard/_dashboard.dart';
import 'package:mobile/components/sidePanel/_mainSidePanel.dart';
import 'package:mobile/components/transaction/borrowing/_mainBorrow.dart';
import 'package:mobile/components/transaction/returning.dart';
import 'package:mobile/notifications/notif.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 add this import

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _accessToken; // store token here

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
    // TODO: your sync logic here
  }

  @override
  Widget build(BuildContext context) {
    if (_accessToken == null) {
      // show loader until token loads
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromARGB(153, 2, 22, 24),
      endDrawer: SidePanel(access_token: _accessToken!), // ✅ pass token
      drawerScrimColor: const Color.fromARGB(0, 157, 35, 35),
      body: SafeArea(
        child: Column(
          children: [
            // 🔔 Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Hero(
                    tag: "istakLogo",
                    child: Image.asset(
                      "assets/fullLogo.png",
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
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.bars,
                      color: Color.fromARGB(255, 185, 170, 157),
                      size: 28,
                    ),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
              ),
            ),

            // ✅ Borrow & Return buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BorrowScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 7, 141, 7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Borrow',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w500,
                          fontSize: 30,
                          color: const Color.fromARGB(255, 20, 16, 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReturnItem()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 7, 141, 7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Return',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w500,
                          fontSize: 30,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Dashboard with pull-to-refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                backgroundColor: Colors.transparent,
                color: Colors.yellow,
                displacement: 40,
                child: const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: Dashboard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
