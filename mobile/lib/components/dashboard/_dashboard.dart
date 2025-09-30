import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile/components/dashboard/transactionList.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      String? storedItems = prefs.getString("borrowedItems");
      if (storedItems != null) {
        setState(() {
          borrowedItems = jsonDecode(storedItems);
        });
      }
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Let TransactionList handle its own scrolling
        Expanded(child: TransactionList()),
      ],
    );
  }
}
