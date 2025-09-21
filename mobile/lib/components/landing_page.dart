import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/dashboard/_dashboard.dart';
import 'package:mobile/components/sidePanel/_mainSidePanel.dart';
import 'package:mobile/components/transaction/borrow.dart';
import 'package:mobile/components/transaction/returning.dart';
import 'package:mobile/notifications/notif.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _refreshDashboard() async {
    // Example: wait 2s and reload data
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      // TODO: trigger your API call / update logic
      print("Dashboard refreshed!");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromRGBO(36, 27, 7, .6),
      endDrawer: const SidePanel(), // ✅ use the new widget
      drawerScrimColor: const Color.fromARGB(0, 157, 35, 35),
      body: SafeArea(
        child: Column(
          children: [
            // Header with Logo and Menu
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
                      Icons.notifications,
                      color: Color.fromARGB(255, 206, 192, 152),
                      size: 28,
                    ),
                    onPressed: () {
                      // _scaffoldKey.currentState?.openEndDrawer();
                      showDialog(
                        context: context,
                        builder: (context) => const NotificationScreen(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.menu,
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

            // Borrow & Return Buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 16),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Borrow()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 56, 39, 17),
                        foregroundColor: const Color.fromARGB(
                          255,
                          178,
                          178,
                          178,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Borrow',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w300,
                          fontSize: 30,
                          color: const Color.fromARGB(255, 195, 171, 126),
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
                        backgroundColor: const Color.fromARGB(255, 56, 39, 17),
                        foregroundColor: const Color.fromARGB(
                          255,
                          178,
                          178,
                          178,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Return',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w300,
                          fontSize: 30,
                          color: const Color.fromARGB(255, 195, 171, 126),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Only one scrollable Dashboard with pull-to-refresh
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                backgroundColor: Colors.transparent, // ✅ no background
                color: Colors.yellow, // ✅ rotating icon color
                displacement: 40, // optional: distance from top
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  child: const Dashboard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
