import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/transaction/transactionMainPage.dart';
import 'package:mobile/components/dashboard/mainDashboard.dart';
import 'package:mobile/components/dashboard/borrower.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const SelectTask(), // Borrow/Return Module
    const Dashboard(), // Inventory Table
    const Borrower(), // Users
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // keep gradient background under everything
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 13, 20, 11),
              Color.fromARGB(255, 40, 38, 38),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.black.withOpacity(0.7), // translucent
              elevation: 0,
              centerTitle: true,
              title: Hero(
                tag: "istakLogo",
                child: Image.asset(
                  "assets/fullLogo.png",
                  width: 120,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            body: _pages[_selectedIndex],
            bottomNavigationBar: NavigationBarTheme(
              data: NavigationBarThemeData(
                labelTextStyle: MaterialStateProperty.all(
                  GoogleFonts.ibmPlexMono(
                    color: const Color(0xFFCC9966),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                iconTheme: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return const IconThemeData(color: Color(0xFFCC9966));
                  }
                  return const IconThemeData(color: Colors.white70);
                }),
              ),
              child: NavigationBar(
                backgroundColor: Colors.black.withOpacity(0.5),
                elevation: 0,
                indicatorColor: Colors.white24,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.task_alt),
                    label: "Tasks",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory),
                    label: "Inventory",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people),
                    label: "Users",
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
