import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/dashboard/transactionList.dart';
import 'package:mobile/components/dashboard/features.dart';
import 'package:mobile/components/transaction/syncTransaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/components/dashboard/itemList.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool loading = true;
  List<dynamic> borrowedItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Retrieve saved items
      String? storedItems = prefs.getString("borrowedItems");
      if (storedItems != null) {
        setState(() {
          borrowedItems = jsonDecode(storedItems);
        });
      }

      await SyncTransactions.syncTransactions(context, type: 'all');
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      displacement: 60,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Most Borrowed Items Section =====
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 43, 38, 13),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                "Most Borrowed Items",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 195, 171, 126),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Features(),
            const SizedBox(height: 20),

            // ===== Transactions Section =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 43, 38, 13),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                "Transactions",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 195, 171, 126),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const TransactionList(),
            const SizedBox(height: 20),

            // ===== Inventory Section =====
            const Itemlist(),
          ],
        ),
      ),
    );
  }
}
