import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/itemTable.dart';
import 'package:mobile/components/returning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/components/qr_scanner.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchItems();
  }

  Future<void> fetchItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      debugPrint("Access token: $token");

      if (token == null) {
        setState(() {
          error = "User not authenticated";
          loading = false;
        });
        return;
      }

      final url = Uri.parse(API.getItems);
      debugPrint("Fetching from: $url");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint("Decoded response: $decoded");
        setState(() {
          items = decoded;
          loading = false;
        });
        debugPrint("Items loaded: ${items.length}");
      } else {
        setState(() {
          error =
              "Failed to load items: ${response.statusCode} - ${response.body}";
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Exception: $e");
      setState(() {
        error = "Error: $e";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent, // 👈 important
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(0, 197, 197, 197),
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu,
                color: Color.fromARGB(255, 150, 150, 150),
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Hero(
            tag: "istakLogo",
            child: Image.asset(
              "assets/fullLogo.png",
              width: 120,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
          centerTitle: true,
        ),
        drawer: Drawer(
          child: Container(
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
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: const Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home, color: Colors.white),
                  title: const Text(
                    'Home',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white),
                  title: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    // TODO: Implement settings route
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
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
            ),
            Column(
              children: [
                Expanded(
                  child: ItemTable(
                    items: items,
                    loading: loading,
                    error: error,
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "scanQR",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRScanner()),
                );
              },
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              tooltip: 'Scan QR',
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: "returnItem",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReturnItem()),
                );
              },
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.assignment_return, color: Colors.white),
              tooltip: 'Return Item',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
