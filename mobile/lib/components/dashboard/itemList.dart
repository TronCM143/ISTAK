import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/helperFunction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legend.dart';

class Itemlist extends StatefulWidget {
  const Itemlist({super.key});

  @override
  State<Itemlist> createState() => _ItemlistState();
}

class _ItemlistState extends State<Itemlist> {
  String selectedFilter = "All";
  List<dynamic> items = []; // Explicitly typed as dynamic to match jsonDecode
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

      if (token == null) {
        setState(() {
          error = "User not authenticated";
          loading = false;
        });
        return;
      }

      final url = Uri.parse(API.getItems);
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          items = decoded is List ? decoded : []; // Ensure items is a List
          loading = false;
        });
        Items.getItems(items); // Pass items to helper function if needed
      } else {
        setState(() {
          error = "Failed to load items: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
        loading = false;
      });
    }
  }

  List<dynamic> getFilteredItems() {
    final now = DateTime.now();
    return items.where((item) {
      final status = item["status"]?.toLowerCase();
      final lastBorrowed = item["last_borrowed"] != null
          ? DateTime.parse(item["last_borrowed"])
          : null;
      bool isOverdue =
          lastBorrowed != null &&
          lastBorrowed.isBefore(now.subtract(const Duration(days: 7)));

      if (selectedFilter == 'All') return true;
      if (selectedFilter == 'Available') return status == 'available';
      if (selectedFilter == 'Borrowed') return status == 'borrowed';
      if (selectedFilter == 'Overdues') return isOverdue;
      return false;
    }).toList();
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'borrowed':
        return Colors.yellow;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = getFilteredItems();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Header =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 43, 38, 13),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            "Inventory",
            style: GoogleFonts.ibmPlexMono(
              color: const Color.fromARGB(255, 195, 171, 126),
              fontSize: 18,
              fontWeight: FontWeight.w300,
              decoration: TextDecoration.none,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ===== Filter Row =====
        Row(
          children: [
            const LegendIcon(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
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
                    children: ['All', 'Available', 'Borrowed', 'Overdues'].map((
                      filter,
                    ) {
                      final bool isSelected = selectedFilter == filter;
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
                              fontSize: 20,
                              decoration: TextDecoration.none,
                              color: isSelected
                                  ? const Color.fromARGB(255, 195, 171, 126)
                                  : const Color.fromARGB(255, 89, 78, 56),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ===== Item Table =====
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 200, // Minimum height for small item lists
                  maxHeight:
                      constraints.maxHeight, // Respect parent constraints
                ),

                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics:
                      const ClampingScrollPhysics(), // Prevent overscrolling
                  child: DataTable(
                    columnSpacing: 16.0, // Reduce spacing between columns
                    horizontalMargin: 16.0, // Add margin for better padding
                    showBottomBorder: false,
                    dividerThickness: 0,
                    headingRowHeight: 40.0, // Reduced for compactness
                    dataRowHeight: 60.0,
                    columns: const [
                      DataColumn(
                        label: Text(
                          "Status",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Item Name",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Condition",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Image",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                    rows: filteredItems.map((item) {
                      final String? status = item["status"];
                      final String? condition = item["condition"];
                      final String? imageUrl = item["image"];

                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              constraints: const BoxConstraints(
                                maxWidth: 150,
                              ), // Limit width
                              child: Text(
                                item["item_name"] ?? "N/A",
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              constraints: const BoxConstraints(
                                maxWidth: 100,
                              ), // Limit width
                              child: Text(
                                condition ?? "N/A",
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            imageUrl != null && imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      imageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            Icons.image_not_supported,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                : Icon(
                                    Icons.image_not_supported,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
