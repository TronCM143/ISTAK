import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'dart:convert';
import 'package:mobile/components/utils/helperFunction.dart';
import 'package:mobile/components/utils/quit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Itemlist extends StatefulWidget {
  const Itemlist({super.key});

  @override
  State<Itemlist> createState() => _ItemlistState();
}

class _ItemlistState extends State<Itemlist> with TickerProviderStateMixin {
  String selectedFilter = "All";
  String searchQuery = "";
  List<dynamic> items = [];
  bool loading = true;
  String error = "";
  String? _accessToken;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _refreshController;
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
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
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

      final url = Uri.parse(dotenv.env['GET_ITEMS']!);
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
      final itemName = (item["item_name"] as String? ?? "").toLowerCase();
      final query = searchQuery.toLowerCase();

      final transactions = item["transactions"] ?? [];
      final latestTransaction = transactions.isNotEmpty
          ? transactions.reduce(
              (a, b) =>
                  DateTime.parse(
                    a["borrow_date"],
                  ).isAfter(DateTime.parse(b["borrow_date"]))
                  ? a
                  : b,
            )
          : null;
      final status =
          latestTransaction != null && latestTransaction["status"] == "borrowed"
          ? 'borrowed'
          : 'available';

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
        return const Color(0xFF34C759); // Green
      case 'borrowed':
        return const Color(0xFFFFB300); // Yellow
      default:
        return const Color(0xFFA8B0B2); // Muted foreground
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = getFilteredItems();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      body: Container(
        margin: const EdgeInsets.only(
          top: 130,
          left: 16,
          right: 16,
          bottom: 120,
        ),
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(
            borderRadius: const Radius.circular(30),
          ),
          settings: const LiquidGlassSettings(
            thickness: 50, // controls optical depth (refraction)
            glassColor: Color.fromARGB(26, 65, 65, 65), // dark translucent tint
            lightIntensity: 1.25, // highlight brightness
            ambientStrength: 0.5, // soft glow
            saturation: 1.05,
          ),
          child: Container(
            //  height: 900,
            // decoration: BoxDecoration(
            //   color: Colors.white.withOpacity(0.05),
            //   borderRadius: BorderRadius.circular(12),
            //   border: Border.all(
            //     color: Colors.white.withOpacity(0.18),
            //     width: 1,
            //   ),
            // ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10), // Move content lower by 100px
                    // Header Part: Title and Refresh
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items',
                          style: GoogleFonts.ibmPlexMono(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        RotationTransition(
                          turns: Tween(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(_refreshController),
                          child: IconButton(
                            icon: const Icon(
                              Icons.sync,
                              color: Color(0xFF34C759),
                              size: 24,
                            ),
                            onPressed: () async {
                              _refreshController.repeat();
                              await _fadeController.reverse();
                              await fetchItems();
                              if (mounted) {
                                await _fadeController.forward();
                                _refreshController.reset();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search Bar without LiquidGlass
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          _fadeController.forward();
                        }
                      },
                      child: AnimatedScale(
                        scale: searchQuery.isEmpty ? 1.0 : 1.05,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: 'Search by item name...',
                              hintStyle: GoogleFonts.ibmPlexMono(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white70,
                              ),
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
                      ),
                    ),
                    // Filter Buttons without LiquidGlass
                    Container(
                      // decoration: BoxDecoration(
                      //   color: Colors.white.withOpacity(0.05),
                      //   borderRadius: BorderRadius.circular(10),
                      //   border: Border.all(
                      //     color: Colors.white.withOpacity(0.18),
                      //     width: 1,
                      //   ),
                      // ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: ['All', 'Available', 'Borrowed'].map((
                                  filter,
                                ) {
                                  final bool isSelected =
                                      selectedFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedFilter = filter;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutBack,
                                        transform: Matrix4.identity()
                                          ..scale(isSelected ? 1.05 : 1.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(
                                                    0xFF34C759,
                                                  ).withOpacity(0.3)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              10,
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
                                                  ? Colors.white
                                                  : const Color(0xFFA8B0B2),
                                            ),
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
                    ),
                    const SizedBox(height: 1),
                    // Column Headers without LiquidGlass
                    Container(
                      // margin: const EdgeInsets.only(bottom: 8),
                      // decoration: BoxDecoration(
                      //   color: Colors.white.withOpacity(0.05),
                      //   borderRadius: BorderRadius.circular(10),
                      //   border: Border.all(
                      //     color: Colors.white.withOpacity(0.18),
                      //     width: 1,
                      //   ),
                      // ),
                      child: ClipRRect(
                        //      borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '',
                                    style: GoogleFonts.ibmPlexMono(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '  Item Name',
                                    style: GoogleFonts.ibmPlexMono(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '  Condition',
                                    style: GoogleFonts.ibmPlexMono(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Last Borrowed',
                                    style: GoogleFonts.ibmPlexMono(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Item List without LiquidGlass
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
                                  GestureDetector(
                                    onTap: () async {
                                      _refreshController.repeat();
                                      await _fadeController.reverse();
                                      await fetchItems();
                                      if (mounted) {
                                        await _fadeController.forward();
                                        _refreshController.reset();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF34C759,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.18),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Retry',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: const Color(0xFF34C759),
                                        ),
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
                              padding: const EdgeInsets.all(1.0),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final transactions = item["transactions"] ?? [];
                                final latestTransaction =
                                    transactions.isNotEmpty
                                    ? transactions.reduce(
                                        (a, b) =>
                                            DateTime.parse(
                                              a["borrow_date"],
                                            ).isAfter(
                                              DateTime.parse(b["borrow_date"]),
                                            )
                                            ? a
                                            : b,
                                      )
                                    : null;
                                final status =
                                    latestTransaction != null &&
                                        latestTransaction["status"] ==
                                            "borrowed"
                                    ? "borrowed"
                                    : "available";
                                final condition =
                                    item["condition"] as String? ?? "N/A";
                                final imageUrl = item["image"] as String? ?? "";
                                final lastBorrowDate = latestTransaction != null
                                    ? latestTransaction["borrow_date"]
                                              ?.toString() ??
                                          "None"
                                    : "None";

                                return AnimatedBuilder(
                                  animation: _fadeAnimation,
                                  builder: (context, child) {
                                    final animation =
                                        Tween<double>(
                                          begin: 0.8,
                                          end: 1.0,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: _fadeAnimation,
                                            curve: Interval(
                                              (index / filteredItems.length) *
                                                  0.5,
                                              1.0,
                                              curve: Curves.easeOutBack,
                                            ),
                                          ),
                                        );
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    //  margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),

                                      border: Border.all(
                                        color: Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                // color: Colors.white.withOpacity(
                                                //   0.08,
                                                // ),
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  //color: getStatusColor(status),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Container(
                                                color: Colors.white.withOpacity(
                                                  0.08,
                                                ),
                                                width: 40,
                                                height: 40,
                                                margin: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: imageUrl.isNotEmpty
                                                    ? GestureDetector(
                                                        onTap: () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) => Dialog(
                                                              backgroundColor:
                                                                  Colors
                                                                      .transparent,
                                                              insetPadding:
                                                                  const EdgeInsets.all(
                                                                    16,
                                                                  ),
                                                              child: GestureDetector(
                                                                onTap: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(),
                                                                child: InteractiveViewer(
                                                                  child: Image.network(
                                                                    imageUrl,
                                                                    fit: BoxFit
                                                                        .contain,
                                                                    errorBuilder:
                                                                        (
                                                                          context,
                                                                          error,
                                                                          stackTrace,
                                                                        ) => const Center(
                                                                          child: Icon(
                                                                            Icons.broken_image,
                                                                            size:
                                                                                80,
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
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child: Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) => Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Colors.white,
                                                      ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  item["item_name"]
                                                          as String? ??
                                                      "N/A",
                                                  style:
                                                      GoogleFonts.ibmPlexMono(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  condition,
                                                  style:
                                                      GoogleFonts.ibmPlexMono(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  lastBorrowDate,
                                                  style:
                                                      GoogleFonts.ibmPlexMono(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
          ),
        ),
      ),
      endDrawer: _accessToken != null
          ? SidePanel(access_token: _accessToken!)
          : null,
      drawerScrimColor: const Color.fromARGB(0, 157, 35, 35),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}
