import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/helperFunction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legend.dart';

class Itemlist extends StatefulWidget {
  const Itemlist({super.key});

  @override
  State<Itemlist> createState() => _ItemlistState();
}

class _ItemlistState extends State<Itemlist>
    with SingleTickerProviderStateMixin {
  String selectedFilter = "All";
  List<dynamic> items = [];
  bool loading = true;
  String error = "";
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
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
          items = decoded is List ? decoded : [];
          loading = false;
          error = "";
        });
        Items.getItems(items);
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
    return items.where((item) {
      final isAvailable = item["current_transaction"] == null;
      final status = isAvailable ? 'available' : 'borrowed';

      if (selectedFilter == 'All') return true;
      if (selectedFilter == 'Available') return status == 'available';
      if (selectedFilter == 'Borrowed') return status == 'borrowed';
      return false;
    }).toList();
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF34C759); // --primary (green)
      case 'borrowed':
        return const Color(0xFFFFB300); // Yellow
      default:
        return const Color(0xFFA8B0B2); // --muted-foreground
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = getFilteredItems();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.only(left: 1.0, right: 1.0),

        child: Card(
          color: Colors.transparent, // Transparent background

          elevation: 2,

          child: Padding(
            padding: const EdgeInsets.only(left: 1.0, right: 1.0),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Inventory",
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFFF5F7F5), // --card-foreground
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Row
                Row(
                  children: [
                    const LegendIcon(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'Available', 'Borrowed'].map((
                            filter,
                          ) {
                            final bool isSelected = selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedFilter = filter;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF34C759) // --primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    filter,
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? const Color(
                                              0xFF1A3C34,
                                            ) // --primary-foreground
                                          : const Color(
                                              0xFFA8B0B2,
                                            ), // --muted-foreground
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Table
                if (loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF34C759), // --primary
                    ),
                  )
                else if (error.isNotEmpty)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        error,
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFD33F49), // --destructive
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          await _fadeController.reverse();
                          await fetchItems();
                          if (mounted) {
                            await _fadeController.forward();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759), // --primary
                          foregroundColor: const Color(
                            0xFF1A3C34,
                          ), // --primary-foreground
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(
                              0xFF1A3C34,
                            ), // --primary-foreground
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.transparent, // Transparent background
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.transparent, // Transparent background
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 150,
                                child: Text(
                                  "Item Name",
                                  style: GoogleFonts.ibmPlexMono(
                                    color: const Color(0xFFF5F7F5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                width: 100,
                                child: Text(
                                  "Condition",
                                  style: GoogleFonts.ibmPlexMono(
                                    color: const Color(0xFFF5F7F5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              SizedBox(width: 35),
                              Container(
                                width: 100,
                                child: Text(
                                  "Image",
                                  style: GoogleFonts.ibmPlexMono(
                                    color: const Color(0xFFF5F7F5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table Rows
                        SizedBox(
                          height: 300, // Fixed height for scrollable table
                          child: ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final status = item["current_transaction"] == null
                                  ? "available"
                                  : "borrowed";
                              final condition =
                                  item["condition"] as String? ?? "N/A";
                              final imageUrl = item["image"] as String? ?? "";

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors
                                          .transparent, // Transparent divider
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: getStatusColor(status),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      width: 140,
                                      child: Text(
                                        item["item_name"] as String? ?? "N/A",
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      width: 90,
                                      child: Text(
                                        condition,
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 60),
                                    Container(
                                      width: 50,
                                      child: imageUrl.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => Dialog(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    insetPadding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    child: GestureDetector(
                                                      onTap: () => Navigator.of(
                                                        context,
                                                      ).pop(),
                                                      child: InteractiveViewer(
                                                        child: Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.contain,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) => const Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                  size: 80,
                                                                  color: Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.network(
                                                  imageUrl,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.image_not_supported,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}
