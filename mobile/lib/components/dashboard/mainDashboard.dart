import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/dashboard/transactions.dart';
import 'package:mobile/components/dashboard/features.dart';
import 'package:mobile/components/dashboard/legend.dart';
import 'package:mobile/components/helperFunction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/dashboard/inventory.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List items = [];
  bool loading = true;
  String? error;
  String selectedFilter = 'All'; // Default filter

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
        setState(() {
          items = decoded;
          loading = false;
        });
        debugPrint("Items loaded: ${items.length}");
        Items.getItems(items);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: GoogleFonts.ibmPlexMono(
            color: colorScheme.error,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none, // ✅ No underline
          ),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Most Borrowed Items Section =====
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 43, 38, 13), // dark brown
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "Most Borrowed Items",
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color.fromARGB(255, 195, 171, 126),
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.none, // ✅ No underline
                  ),
                ),
              ),

              const SizedBox(height: 10),
              const Features(),
              const SizedBox(height: 20),

              // ===== Borrowers List Section =====
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 43, 38, 13), // dark brown
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  "Transactions",
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color.fromARGB(255, 195, 171, 126),
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.none, // ✅ No underline
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Transactions(),
              const SizedBox(height: 20),

              // ===== Filter Row =====
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(0),
                    child: LegendIcon(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'Available', 'Borrowed', 'Overdues']
                              .map((filter) {
                                final bool isSelected =
                                    selectedFilter == filter;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedFilter = filter;
                                      });
                                    },
                                    child: Text(
                                      filter,
                                      style: GoogleFonts.ibmPlexMono(
                                        textStyle: const TextStyle(
                                          fontSize: 20,
                                          decoration: TextDecoration
                                              .none, // ✅ No underline
                                        ),
                                        color: isSelected
                                            ? const Color.fromARGB(
                                                255,
                                                195,
                                                171,
                                                126,
                                              )
                                            : const Color.fromARGB(
                                                255,
                                                89,
                                                78,
                                                56,
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ===== Inventory Section =====
              Inventory(items: items, selectedFilter: selectedFilter),
            ],
          ),
        ),
      ],
    );
  }
}
