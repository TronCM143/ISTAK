import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile/apiURl.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TransactionList extends StatefulWidget {
  const TransactionList({super.key});

  static final GlobalKey<_TransactionsState> globalKey =
      GlobalKey<_TransactionsState>();

  @override
  State<TransactionList> createState() => _TransactionsState();
}

class _TransactionsState extends State<TransactionList>
    with SingleTickerProviderStateMixin {
  List<dynamic> transactions = [];
  List<dynamic> filteredTransactions = [];
  bool loading = true;
  String error = "";
  int retryCount = 0;
  static const int maxRetries = 3;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

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
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = "";
    });
    debugPrint(
      "Starting fetchTransactions, loading: $loading, error: '$error'",
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      debugPrint("Fetching transactions - Token: ${token ?? 'null'}");

      if (token == null) {
        setState(() {
          error = "Please log in to view transactions";
          loading = false;
        });
        debugPrint("Authentication failed: $error");
        return;
      }

      if (!RegExp(
        r'^https?://[a-zA-Z0-9\.\-]+(:\d+)?/?$',
      ).hasMatch(API.baseUrl)) {
        setState(() {
          error = "Invalid API base URL: ${API.baseUrl}";
          loading = false;
        });
        debugPrint("Invalid API base URL: ${API.baseUrl}");
        return;
      }

      final url = Uri.parse('${API.baseUrl}/api/transactions/');
      debugPrint("Requesting URL: $url");

      final response = await http
          .get(
            url,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception("Request timed out");
            },
          );

      debugPrint("Response status: ${response.statusCode}");
      debugPrint(
        "Response body: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}",
      );

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (e) {
          setState(() {
            error = "Invalid response format: $e";
            loading = false;
          });
          debugPrint("JSON decode error: $e");
          return;
        }

        if (data is! List) {
          setState(() {
            error =
                "Invalid response format: Expected a list, got ${data.runtimeType}";
            loading = false;
          });
          debugPrint("Invalid data type: ${data.runtimeType}");
          return;
        }

        final userTransactions = data;
        if (mounted) {
          setState(() {
            transactions = userTransactions.map((transaction) {
              final borrower = transaction['borrower'] is Map<String, dynamic>
                  ? transaction['borrower'] as Map<String, dynamic>?
                  : null;
              final items = transaction['items'] is List
                  ? transaction['items'] as List
                  : [];
              debugPrint(
                "Transaction items: ${jsonEncode(items)}",
              ); // Debug items

              if (transaction['borrower'] is! Map<String, dynamic>?) {
                debugPrint(
                  "Unexpected borrower type: ${transaction['borrower'].runtimeType}, value: ${transaction['borrower']}",
                );
              }
              if (transaction['items'] is! List) {
                debugPrint(
                  "Unexpected items type: ${transaction['items'].runtimeType}, value: ${transaction['items']}",
                );
              }

              final imageUrl = borrower != null
                  ? (borrower['image'] as String?)?.trim()
                  : null;

              debugPrint("Raw borrower data: ${jsonEncode(borrower)}");
              debugPrint("Raw image URL: $imageUrl");

              return {
                'return_date': (transaction['return_date'] as String?) ?? "N/A",
                'borrow_date': (transaction['borrow_date'] as String?) ?? "N/A",
                'item_name': items.isNotEmpty
                    ? (items[0]['item_name'] as String?) ?? "Unknown Item"
                    : "Unknown Item",
                'borrower_name': borrower != null
                    ? (borrower['name'] as String?) ?? "Unknown"
                    : transaction['borrower_name'] as String? ?? "Unknown",
                'school_id': borrower != null
                    ? (borrower['school_id'] as String?) ?? "N/A"
                    : transaction['school_id'] as String? ?? "N/A",
                'status':
                    (transaction['status'] as String?)?.toUpperCase() ??
                    "UNKNOWN",
                'image': imageUrl,
                'items': items,
              };
            }).toList();
            filteredTransactions = transactions;
            loading = false;
            retryCount = 0;
          });
          debugPrint("Fetched ${transactions.length} transactions");
        }
      } else if (response.statusCode >= 500 && retryCount < maxRetries) {
        retryCount++;
        debugPrint("Server error, retrying ($retryCount/$maxRetries)...");
        await Future.delayed(Duration(seconds: 2 * retryCount));
        return fetchTransactions();
      } else {
        if (mounted) {
          setState(() {
            error = response.statusCode == 401
                ? "Authentication failed. Please log in again."
                : "Failed to load transactions: ${response.statusCode} - ${response.body}";
            loading = false;
          });
        }
        debugPrint("API error: $error");
      }
    } catch (e, stackTrace) {
      debugPrint("Exception caught: $e, Stack trace: $stackTrace");
      if (e.toString().contains("timed out") && retryCount < maxRetries) {
        retryCount++;
        debugPrint("Timeout, retrying ($retryCount/$maxRetries)...");
        await Future.delayed(Duration(seconds: 2 * retryCount));
        return fetchTransactions();
      }
      if (mounted) {
        setState(() {
          error = "Error fetching transactions: $e";
          loading = false;
        });
      }
    }
    debugPrint(
      "fetchTransactions completed, loading: $loading, error: '$error', transactions: ${transactions.length}",
    );
  }

  void _filterTransactions(String query) {
    setState(() {
      filteredTransactions = transactions.where((transaction) {
        final borrowerName = transaction['borrower_name'].toLowerCase();
        final schoolId = transaction['school_id'].toLowerCase();
        final itemName = transaction['item_name'].toLowerCase();
        final searchQuery = query.toLowerCase();
        return borrowerName.contains(searchQuery) ||
            schoolId.contains(searchQuery) ||
            itemName.contains(searchQuery);
      }).toList();
    });
    debugPrint("Filtered transactions: ${filteredTransactions.length}");
  }

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'BORROWED':
        return const Color(0xFFFFB300); // Yellow
      case 'RETURNED':
        return const Color(0xFF34C759); // Green
      default:
        return const Color(0xFFA8B0B2); // Muted
    }
  }

  void clearImageCache(String? imageUrl) {
    if (imageUrl != null) {
      CachedNetworkImageProvider(imageUrl).evict();
      debugPrint("Cleared image cache for $imageUrl");
    }
  }

  void _showItemsDialog(BuildContext context, List<dynamic> items) {
    debugPrint(
      "Showing dialog with ${items.length} items: ${jsonEncode(items)}",
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.white.withOpacity(0.05),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Borrowed Items (${items.length})',
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFF5F7F5),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                          minWidth: 200, // Ensure dialog is wide enough
                        ),
                        child: items.isEmpty
                            ? Text(
                                'No items borrowed',
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color(0xFFA8B0B2),
                                  fontSize: 12,
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: items.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final itemName =
                                        item['item_name'] as String? ??
                                        'Unknown Item ${index + 1}';
                                    final itemImage = item['image'] as String?;
                                    debugPrint(
                                      "Rendering item $index: $itemName, image: $itemImage",
                                    );
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          ClipOval(
                                            child:
                                                itemImage != null &&
                                                    itemImage.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: itemImage,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) =>
                                                        const CircularProgressIndicator(
                                                          color: Color(
                                                            0xFF34C759,
                                                          ),
                                                        ),
                                                    errorWidget:
                                                        (context, url, error) {
                                                          debugPrint(
                                                            "Item image load error for URL: $url, error: $error",
                                                          );
                                                          return const Icon(
                                                            Icons.image,
                                                            color: Colors.white,
                                                            size: 40,
                                                          );
                                                        },
                                                  )
                                                : const Icon(
                                                    Icons.image,
                                                    color: Colors.white,
                                                    size: 40,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              itemName,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color(0xFF34C759),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "Building TransactionList, constraints: ${BoxConstraints(maxHeight: MediaQuery.of(context).size.height, maxWidth: MediaQuery.of(context).size.width)}",
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint("TransactionList constraints: $constraints");
        return Container(
          color: Colors.grey[900],
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: GoogleFonts.ibmPlexMono(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by name, school ID',
                          hintStyle: GoogleFonts.ibmPlexMono(
                            color: const Color(0xFFA8B0B2),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFFA8B0B2),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[850],
                        ),
                        onChanged: _filterTransactions,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            debugPrint("View All clicked");
                          },
                          child: Text(
                            'View All',
                            style: GoogleFonts.ibmPlexMono(
                              color: const Color(0xFF34C759),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: loading
                          ? const SliverToBoxAdapter(
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            )
                          : error.isNotEmpty
                          ? SliverToBoxAdapter(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      error,
                                      style: GoogleFonts.ibmPlexMono(
                                        color: const Color(0xFFD33F49),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await _fadeController.reverse();
                                        await fetchTransactions();
                                        if (mounted) {
                                          await _fadeController.forward();
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF34C759,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF1A3C34,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: Text(
                                        'Retry',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: const Color(0xFF1A3C34),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filteredTransactions.isEmpty
                          ? SliverToBoxAdapter(
                              child: Center(
                                child: Text(
                                  "No transactions available",
                                  style: GoogleFonts.ibmPlexMono(
                                    color: Color(0xFFA8B0B2),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final transaction = filteredTransactions[index];
                                final status = transaction['status'] as String;
                                final borrowDate =
                                    transaction['borrow_date'] != "N/A"
                                    ? DateFormat("MMM d, yyyy").format(
                                        DateTime.parse(
                                          transaction['borrow_date'],
                                        ),
                                      )
                                    : "—";
                                final returnDate =
                                    transaction['return_date'] != "N/A"
                                    ? DateFormat("MMM d, yyyy").format(
                                        DateTime.parse(
                                          transaction['return_date'],
                                        ),
                                      )
                                    : "—";
                                final borrowerName =
                                    transaction['borrower_name'] as String;
                                final schoolId =
                                    transaction['school_id'] as String;
                                final image = transaction['image'] as String?;
                                final items =
                                    transaction['items'] as List<dynamic>;
                                final displayItemName = items.isNotEmpty
                                    ? items.length > 1
                                          ? "${items[0]['item_name']} (+${items.length - 1})"
                                          : items[0]['item_name'] as String? ??
                                                "Unknown Item"
                                    : "Unknown Item";

                                return GestureDetector(
                                  onTap: () => _showItemsDialog(context, items),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 5,
                                          sigmaY: 5,
                                        ),
                                        child: Container(
                                          color: Colors.white.withOpacity(0.05),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ClipOval(
                                                child:
                                                    image != null &&
                                                        image.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: image,
                                                        width: 40,
                                                        height: 40,
                                                        fit: BoxFit.cover,
                                                        placeholder:
                                                            (context, url) =>
                                                                const CircularProgressIndicator(
                                                                  color: Color(
                                                                    0xFF34C759,
                                                                  ),
                                                                ),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              url,
                                                              error,
                                                            ) {
                                                              debugPrint(
                                                                "Image load error for URL: $url, error: $error",
                                                              );
                                                              return const Icon(
                                                                Icons.person,
                                                                color: Colors
                                                                    .white,
                                                                size: 40,
                                                              );
                                                            },
                                                      )
                                                    : const Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                        size: 40,
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            borrowerName,
                                                            style: GoogleFonts.ibmPlexMono(
                                                              color:
                                                                  const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 14,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            schoolId,
                                                            style: GoogleFonts.ibmPlexMono(
                                                              color:
                                                                  const Color(
                                                                    0xFFA8B0B2,
                                                                  ),
                                                              fontSize: 12,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            'Borrowed: $borrowDate',
                                                            style: GoogleFonts.ibmPlexMono(
                                                              color:
                                                                  const Color(
                                                                    0xFFA8B0B2,
                                                                  ),
                                                              fontSize: 10,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            'Returned: $returnDate',
                                                            style: GoogleFonts.ibmPlexMono(
                                                              color:
                                                                  const Color(
                                                                    0xFFA8B0B2,
                                                                  ),
                                                              fontSize: 10,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      displayItemName,
                                                      style:
                                                          GoogleFonts.ibmPlexMono(
                                                            color: const Color(
                                                              0xFFA8B0B2,
                                                            ),
                                                            fontSize: 10,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: getStatusColor(status),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }, childCount: filteredTransactions.length),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
