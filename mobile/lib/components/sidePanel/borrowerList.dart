import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/_landing_page.dart';

class Borrowerlist extends StatefulWidget {
  final String access_token;

  const Borrowerlist({super.key, required this.access_token});

  @override
  State<Borrowerlist> createState() => _BorrowerlistState();
}

class _BorrowerlistState extends State<Borrowerlist>
    with SingleTickerProviderStateMixin {
  List<dynamic> borrowers = [];
  String selectedFilter = 'All';
  bool loading = true;
  String? error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Map<int, List<dynamic>> transactionsCache =
      {}; // Cache transactions by borrower ID

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
    fetchBorrowers();
  }

  Future<void> fetchBorrowers() async {
    setState(() {
      loading = true;
      error = null;
      transactionsCache.clear(); // Clear cache on refresh
    });
    debugPrint("Starting fetchBorrowers, loading: $loading, error: '$error'");

    try {
      final token = widget.access_token;
      debugPrint(
        "Fetching borrowers - Token: ${token.isEmpty ? 'empty' : 'valid'}",
      );

      if (token.isEmpty) {
        setState(() {
          error = "Please log in to view borrowers";
          loading = false;
        });
        debugPrint("Authentication failed: $error");
        return;
      }

      final url = Uri.parse('${API.baseUrl}/api/borrowers/');
      debugPrint("Requesting URL: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.access_token}",
        },
      );

      debugPrint("Response Status: ${response.statusCode}");
      debugPrint(
        "Response Body: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            borrowers = data;
            loading = false;
          });
          debugPrint("Fetched ${borrowers.length} borrowers: $borrowers");
        } else {
          throw Exception("Invalid response format: Expected a list");
        }
      } else {
        setState(() {
          error =
              "Failed to load borrowers: ${response.statusCode} - ${response.body}";
          loading = false;
        });
        debugPrint("API error: $error");
      }
    } catch (e) {
      setState(() {
        error =
            e.toString().contains("Failed host lookup") ||
                e.toString().contains("SocketException")
            ? "No Internet. Failed to fetch borrowers."
            : "Error fetching borrowers: $e";
        loading = false;
      });
      debugPrint("Exception caught: $e");
    }
  }

  Future<List<dynamic>> fetchTransactions(int borrowerId) async {
    if (transactionsCache.containsKey(borrowerId)) {
      debugPrint("Returning cached transactions for borrower $borrowerId");
      return transactionsCache[borrowerId]!;
    }

    try {
      final url = Uri.parse(
        '${API.baseUrl}/api/borrower-transactions/$borrowerId/',
      );
      debugPrint("Fetching transactions for borrower $borrowerId: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.access_token}",
        },
      );

      debugPrint("Transactions Response Status: ${response.statusCode}");
      debugPrint(
        "Transactions Response Body: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}",
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          transactionsCache[borrowerId] = data;
          return data;
        } else {
          throw Exception("Invalid response format: Expected a list");
        }
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(
          "Failed to load transactions: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Error fetching transactions for borrower $borrowerId: $e");
      return [];
    }
  }

  List<dynamic> getFilteredBorrowers() {
    return borrowers.where((borrower) {
      final status = borrower["status"]?.toLowerCase();
      if (selectedFilter == 'All') return true;
      if (selectedFilter == 'Active') return status == 'active';
      if (selectedFilter == 'Inactive') return status == 'inactive';
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBorrowers = getFilteredBorrowers();
    debugPrint(
      "Building Borrowerlist, borrowers: ${filteredBorrowers.length}, data: $filteredBorrowers",
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E), // --background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF5F7F5)),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Home()),
            );
          },
        ),
        title: Text(
          'Borrowers',
          style: GoogleFonts.ibmPlexMono(
            color: const Color(0xFFF5F7F5), // --card-foreground
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFF5F7F5)),
            onPressed: () async {
              await _fadeController.reverse();
              await fetchBorrowers();
              if (mounted) await _fadeController.forward();
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ), // 16px side padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['All', 'Active', 'Inactive'].map((filter) {
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
                const SizedBox(height: 16),
                // Table
                LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth =
                        MediaQuery.of(context).size.width - 32; // 16px padding
                    const baseWidths = [
                      150.0,
                      120.0,
                      100.0,
                    ]; // Name, School ID, Num Items
                    const minColumnWidths = [100.0, 80.0, 80.0]; // Min widths
                    final totalBaseWidth = baseWidths.reduce((a, b) => a + b);
                    final columnWidths = availableWidth < totalBaseWidth
                        ? baseWidths.asMap().entries.map((entry) {
                            final index = entry.key;
                            final baseWidth = entry.value;
                            final minWidth = minColumnWidths[index];
                            final scaledWidth =
                                (baseWidth / totalBaseWidth) * availableWidth;
                            return scaledWidth < minWidth
                                ? minWidth
                                : scaledWidth;
                          }).toList()
                        : baseWidths;

                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: minColumnWidths.reduce(
                          (a, b) => a + b,
                        ), // 260px min
                        minHeight: 100,
                        maxHeight:
                            constraints.maxHeight - 100, // Space for filters
                      ),
                      child: loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF34C759), // --primary
                              ),
                            )
                          : error != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  error!,
                                  style: GoogleFonts.ibmPlexMono(
                                    color: const Color(
                                      0xFFD33F49,
                                    ), // --destructive
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _fadeController.reverse();
                                    await fetchBorrowers();
                                    if (mounted)
                                      await _fadeController.forward();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFF34C759,
                                    ), // --primary
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
                          : filteredBorrowers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                "No borrowers found",
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color(
                                    0xFFA8B0B2,
                                  ), // --muted-foreground
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: columnWidths[0],
                                        child: Text(
                                          "Name",
                                          style: GoogleFonts.ibmPlexMono(
                                            color: const Color(0xFFF5F7F5),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: columnWidths[1],
                                        child: Text(
                                          "School ID",
                                          style: GoogleFonts.ibmPlexMono(
                                            color: const Color(0xFFF5F7F5),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: columnWidths[2],
                                        child: Text(
                                          "Items Borrowed",
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
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredBorrowers.length,
                                  itemBuilder: (context, index) {
                                    final borrower = filteredBorrowers[index];
                                    final String? name = borrower["name"];
                                    final String? schoolId =
                                        borrower["school_id"];
                                    final int itemCount =
                                        borrower["transaction_count"] ?? 0;
                                    final int borrowerId = borrower["id"] ?? 0;

                                    return ExpansionTile(
                                      title: Row(
                                        children: [
                                          Expanded(
                                            flex: 2, // Name gets more space
                                            child: Text(
                                              name ?? "N/A",
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2, // School ID also wider
                                            child: Text(
                                              schoolId ?? "N/A",
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1, // Item count smaller
                                            child: Text(
                                              "$itemCount Item${itemCount == 1 ? '' : 's'}",
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),

                                      children: [
                                        FutureBuilder<List<dynamic>>(
                                          future: fetchTransactions(borrowerId),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Padding(
                                                padding: EdgeInsets.all(16),
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Color(0xFF34C759),
                                                    ),
                                              );
                                            } else if (snapshot.hasError) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                child: Text(
                                                  "Error loading transactions",
                                                  style:
                                                      GoogleFonts.ibmPlexMono(
                                                        color: const Color(
                                                          0xFFD33F49,
                                                        ),
                                                        fontSize: 12,
                                                      ),
                                                ),
                                              );
                                            } else {
                                              final transactions =
                                                  snapshot.data ?? [];
                                              return SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    minWidth:
                                                        610, // Total sub-table width
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Sub-Table Header
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            SizedBox(
                                                              width: 80,
                                                              child: Text(
                                                                "Status",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 150,
                                                              child: Text(
                                                                "Item Name",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 100,
                                                              child: Text(
                                                                "Date Borrowed",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 100,
                                                              child: Text(
                                                                "Date Returned",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 90,
                                                              child: Text(
                                                                "Condition Before",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 90,
                                                              child: Text(
                                                                "Condition After",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Sub-Table Rows
                                                      transactions.isEmpty
                                                          ? Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                              child: Text(
                                                                "No transactions",
                                                                style: GoogleFonts.ibmPlexMono(
                                                                  color: const Color(
                                                                    0xFFA8B0B2,
                                                                  ),
                                                                  fontSize: 12,
                                                                  decoration:
                                                                      TextDecoration
                                                                          .none,
                                                                ),
                                                              ),
                                                            )
                                                          : Column(
                                                              children: transactions.map((
                                                                transaction,
                                                              ) {
                                                                final String
                                                                status =
                                                                    transaction["status"]
                                                                        ?.toString() ??
                                                                    "N/A";
                                                                final String
                                                                itemName =
                                                                    transaction["item"]
                                                                        ?.toString() ??
                                                                    "N/A";
                                                                final String
                                                                borrowDate =
                                                                    transaction["borrow_date"]
                                                                        ?.toString() ??
                                                                    "N/A";
                                                                final String
                                                                returnDate =
                                                                    transaction["return_date"]
                                                                        ?.toString() ??
                                                                    "N/A";
                                                                final String
                                                                conditionBefore =
                                                                    transaction["condition_before"]
                                                                        ?.toString() ??
                                                                    "N/A";
                                                                final String
                                                                conditionAfter =
                                                                    transaction["condition_after"]
                                                                        ?.toString() ??
                                                                    "N/A";

                                                                return Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            12,
                                                                      ),
                                                                  decoration: const BoxDecoration(
                                                                    border: Border(
                                                                      bottom: BorderSide(
                                                                        color: Colors
                                                                            .transparent,
                                                                        width:
                                                                            1,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      SizedBox(
                                                                        width:
                                                                            80,
                                                                        child: Tooltip(
                                                                          message:
                                                                              status,
                                                                          child: Text(
                                                                            status,
                                                                            style: GoogleFonts.ibmPlexMono(
                                                                              color:
                                                                                  status ==
                                                                                      'borrowed'
                                                                                  ? const Color(
                                                                                      0xFF34C759,
                                                                                    )
                                                                                  : status ==
                                                                                        'returned'
                                                                                  ? const Color(
                                                                                      0xFFA8B0B2,
                                                                                    )
                                                                                  : const Color(
                                                                                      0xFFD33F49,
                                                                                    ),
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            150,
                                                                        child: Tooltip(
                                                                          message:
                                                                              itemName,
                                                                          child: Text(
                                                                            itemName,
                                                                            style: GoogleFonts.ibmPlexMono(
                                                                              color: const Color(
                                                                                0xFFF5F7F5,
                                                                              ),
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            100,
                                                                        child: Tooltip(
                                                                          message:
                                                                              borrowDate,
                                                                          child: Text(
                                                                            borrowDate,
                                                                            style: GoogleFonts.ibmPlexMono(
                                                                              color: const Color(
                                                                                0xFFF5F7F5,
                                                                              ),
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            100,
                                                                        child: Tooltip(
                                                                          message:
                                                                              returnDate,
                                                                          child: Text(
                                                                            returnDate,
                                                                            style: GoogleFonts.ibmPlexMono(
                                                                              color: const Color(
                                                                                0xFFF5F7F5,
                                                                              ),
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            90,
                                                                        child: Tooltip(
                                                                          message:
                                                                              conditionBefore,
                                                                          child: Text(
                                                                            conditionBefore,
                                                                            style: GoogleFonts.ibmPlexMono(
                                                                              color: const Color(
                                                                                0xFFF5F7F5,
                                                                              ),
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            90,
                                                                        child: Tooltip(
                                                                          message:
                                                                              conditionAfter,
                                                                          child: Text(
                                                                            conditionAfter,
                                                                            style: GoogleFonts.ibmPlexMono(
                                                                              color: const Color(
                                                                                0xFFF5F7F5,
                                                                              ),
                                                                              fontSize: 12,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                    );
                  },
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
    borrowers = [];
    transactionsCache.clear();
    selectedFilter = 'All';
    loading = true;
    error = null;
    super.dispose();
  }
}
