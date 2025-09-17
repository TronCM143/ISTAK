import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/apiURl.dart';

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
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Most Borrowed Items Section =====
          const SizedBox(height: 10),

          // ===== Filter Options with Container =====
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3C2F2F), // Dark brown color
              borderRadius: BorderRadius.circular(
                30,
              ), // 30-pixel rounded corner
            ),
            child: Row(
              children: ['All', 'Available', 'Borrowed', 'Overdues'].map((
                filter,
              ) {
                return Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                    child: Text(
                      filter,
                      style: GoogleFonts.ibmPlexMono(
                        color: selectedFilter == filter
                            ? colorScheme.primary
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // ===== Inventory Table Section =====
          Inventory(items: items, selectedFilter: selectedFilter),
        ],
      ),
    );
  }
}

class Inventory extends StatelessWidget {
  final List items;
  final String selectedFilter;

  const Inventory({
    super.key,
    required this.items,
    required this.selectedFilter,
  });

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

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "N/A";
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsedDate);
    } catch (e) {
      return "N/A";
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = getFilteredItems();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8.0),
        child: DataTable(
          columnSpacing: 24.0,
          dataRowHeight: 60.0,
          headingRowHeight: 48.0,
          headingTextStyle: GoogleFonts.ibmPlexMono(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          dataTextStyle: GoogleFonts.ibmPlexMono(
            color: Colors.white,
            fontSize: 13,
          ),
          decoration: const BoxDecoration(
            color: Color.fromARGB(0, 16, 226, 51),
          ),
          columns: const [
            DataColumn(
              label: Text("Status", style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text("Item Name", style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text(
                "Date Borrowed",
                style: TextStyle(color: Colors.white),
              ),
            ),
            DataColumn(
              label: Text("Image", style: TextStyle(color: Colors.white)),
            ),
          ],
          rows: filteredItems.asMap().entries.map((entry) {
            final dynamic item = entry.value;
            final String? imageUrl = item["image"];
            final String? status = item["status"];
            final String? lastBorrowed = item["last_borrowed"];
            final bool isOverdue = lastBorrowed != null
                ? DateTime.parse(
                    lastBorrowed,
                  ).isBefore(DateTime.now().subtract(const Duration(days: 7)))
                : false;

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getStatusColor(isOverdue ? 'overdue' : status),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    item["item_name"] ?? "N/A",
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    _formatDate(lastBorrowed),
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                ),
                DataCell(
                  imageUrl != null && imageUrl.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showImagePreview(context, imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.broken_image,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
