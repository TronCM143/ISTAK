import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/apiURL.dart';
import 'package:mobile/components/_landing_page.dart';
import 'package:mobile/components/helperFunction.dart';
import 'package:mobile/components/sidePanel/_mainSidePanel.dart';
import 'package:mobile/components/sidePanel/borrowerList.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legend.dart';
import 'package:flutter/cupertino.dart';

class Itemlist extends StatefulWidget {
  const Itemlist({super.key});

  @override
  State<Itemlist> createState() => _ItemlistState();
}

class _ItemlistState extends State<Itemlist>
    with SingleTickerProviderStateMixin {
  String selectedFilter = "All";
  String searchQuery = "";
  List<dynamic> items = [];
  bool loading = true;
  String error = "";
  String? _accessToken;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    _loadAccessToken();
    fetchItems();
  }

  Future<void> _loadAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('access_token');
    });
  }

  Future<void> fetchItems() async {
    setState(() {
      loading = true;
      error = "";
    });
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
        error =
            e.toString().contains("Failed host lookup") ||
                e.toString().contains("SocketException")
            ? "No Internet. Failed to fetch items."
            : "Error: $e";
        loading = false;
      });
    }
  }

  List<dynamic> getFilteredItems() {
    return items.where((item) {
      final isAvailable = item["current_transaction"] == null;
      final status = isAvailable ? 'available' : 'borrowed';
      final itemName = (item["item_name"] as String? ?? "").toLowerCase();
      final query = searchQuery.toLowerCase();

      bool matchesFilter =
          selectedFilter == 'All' ||
          (selectedFilter == 'Available' && status == 'available') ||
          (selectedFilter == 'Borrowed' && status == 'borrowed');
      bool matchesSearch = itemName.contains(query);

      return matchesFilter && matchesSearch;
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          'Inventory',
          style: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          DropdownButton<String>(
            value: selectedFilter,
            dropdownColor: Colors.grey[850],
            icon: const Icon(Icons.filter_list, color: Colors.white),
            items: ['All', 'Available', 'Borrowed']
                .map(
                  (filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(
                      filter,
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedFilter = value!;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await _fadeController.reverse();
              await fetchItems();
              if (mounted) {
                await _fadeController.forward();
              }
            },
          ),
        ],
      ),
      endDrawer: _accessToken != null
          ? SidePanel(access_token: _accessToken!)
          : null,
      drawerScrimColor: const Color.fromARGB(0, 157, 35, 35),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by item name...',
                    hintStyle: GoogleFonts.ibmPlexMono(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
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
                                      ? const Color(0xFF34C759)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? const Color(0xFF1A3C34)
                                        : const Color(0xFFA8B0B2),
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
              // Item List
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF34C759),
                        ),
                      )
                    : error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error,
                              style: GoogleFonts.ibmPlexMono(
                                color: const Color(0xFFD33F49),
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
                                backgroundColor: const Color(0xFF34C759),
                                foregroundColor: const Color(0xFF1A3C34),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Retry',
                                style: GoogleFonts.ibmPlexMono(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: const Color(0xFF1A3C34),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          'No items found',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final status = item["current_transaction"] == null
                              ? "available"
                              : "borrowed";
                          final condition =
                              item["condition"] as String? ?? "N/A";
                          final imageUrl = item["image"] as String? ?? "";
                          final returnDate =
                              item["current_transaction"]?["return_date"]
                                  ?.toString() ??
                              "None";
                          final borrowDate =
                              item["current_transaction"]?["borrow_date"]
                                  ?.toString() ??
                              "None";

                          return Card(
                            color: Colors.grey[850],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  // Status Indicator
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  // Image
                                  Container(
                                    width: 40,
                                    height: 40,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: imageUrl.isNotEmpty
                                        ? GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => Dialog(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  insetPadding:
                                                      const EdgeInsets.all(16),
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
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Icon(
                                                      Icons.image_not_supported,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.image_not_supported,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                  ),
                                  // Item Name
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item["item_name"] as String? ?? "N/A",
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Condition
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      condition,
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Return Date
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      returnDate,
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Borrow Date
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      borrowDate,
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.home),
                    color: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Home()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.book),
                    color: Colors.white,
                    onPressed: () {}, // Disabled, as we're already on Itemlist
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.person),
                    color: Colors.white,
                    onPressed: () {
                      if (_accessToken != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                Borrowerlist(access_token: _accessToken!),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please wait, loading access token...',
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.line_horizontal_3),
                    color: Colors.white,
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
              ),
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
