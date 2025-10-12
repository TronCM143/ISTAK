import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  final List<String> _filterValues = ['ALL', 'AVAILABLE', 'BORROWED'];
  final List<String> _filterLabels = ['All', 'Available', 'Borrowed'];
  String _selectedFilter = 'ALL';

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
    final String baseUrl = dotenv.env['BASE_URL']!;
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

      if (!RegExp(r'^https?://[a-zA-Z0-9\.\-]+(:\d+)?/?$').hasMatch(baseUrl)) {
        setState(() {
          error = "Invalid API base URL: ${baseUrl}";
          loading = false;
        });
        debugPrint("Invalid API base URL: ${baseUrl}");
        return;
      }

      final url = Uri.parse('${baseUrl}/api/transactions/');
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
              debugPrint("Transaction items: ${jsonEncode(items)}");

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
                'id': transaction['id'].toString(), // Convert id to String
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
            loading = false;
            retryCount = 0;
          });
          _applyFilters(_searchController.text);
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

  Future<void> deleteTransaction(String transactionId) async {
    final String baseUrl = dotenv.env['BASE_URL']!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      if (token == null) {
        setState(() {
          error = "Please log in to delete transactions";
        });
        debugPrint("Authentication failed: $error");
        return;
      }

      final url = Uri.parse('${baseUrl}/api/transactions/$transactionId/');
      debugPrint("Deleting transaction at URL: $url");

      final response = await http
          .delete(
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

      debugPrint("Delete response status: ${response.statusCode}");

      if (response.statusCode == 204) {
        if (mounted) {
          setState(() {
            transactions.removeWhere((t) => t['id'] == transactionId);
            _applyFilters(_searchController.text);
          });
          debugPrint("Transaction $transactionId deleted successfully");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Transaction deleted successfully',
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF34C759),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            error = response.statusCode == 401
                ? "Authentication failed. Please log in again."
                : "Failed to delete transaction: ${response.statusCode} - ${response.body}";
          });
          debugPrint("Delete error: $error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error,
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFD33F49),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete exception: $e");
      if (mounted) {
        setState(() {
          error = "Error deleting transaction: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error,
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFD33F49),
          ),
        );
      }
    }
  }

  bool _isOverdue(Map<String, dynamic> transaction) {
    if (transaction['return_date'] == "N/A") return false;
    try {
      final returnDate = DateTime.parse(transaction['return_date']);
      return returnDate.isBefore(
        DateTime.now().subtract(const Duration(days: 1)),
      );
    } catch (e) {
      debugPrint("Error parsing return date: $e");
      return false;
    }
  }

  void _applyFilters(String query) {
    setState(() {
      filteredTransactions = transactions.where((transaction) {
        final borrowerName = transaction['borrower_name'].toLowerCase();
        final schoolId = transaction['school_id'].toLowerCase();
        final itemName = transaction['item_name'].toLowerCase();
        final searchQuery = query.toLowerCase();
        final matchesQuery =
            borrowerName.contains(searchQuery) ||
            schoolId.contains(searchQuery) ||
            itemName.contains(searchQuery);

        bool matchesFilter = false;
        final status = transaction['status'];

        switch (_selectedFilter) {
          case 'ALL':
            matchesFilter = true;
            break;
          case 'AVAILABLE':
            matchesFilter = status == 'RETURNED';
            break;
          case 'BORROWED':
            matchesFilter = status == 'BORROWED';
            break;
        }

        return matchesQuery && matchesFilter;
      }).toList();
    });
    debugPrint("Filtered transactions: ${filteredTransactions.length}");
  }

  Color getStatusColor(Map<String, dynamic> transaction) {
    final status = transaction['status'];
    if (status == 'BORROWED') {
      if (_isOverdue(transaction)) {
        return const Color(0xFFD33F49); // Red for overdue
      }
      return const Color(0xFFFFB300); // Yellow for borrowed
    } else if (status == 'RETURNED') {
      return const Color(0xFF34C759); // Green for returned
    } else {
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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Borrowed Items (${items.length})',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                          minWidth: 200,
                        ),
                        child: items.isEmpty
                            ? Text(
                                'No items borrowed',
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white70,
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
                                                color: Colors.white,
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

  void _showDeleteConfirmation(BuildContext context, String transactionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(
            255,
            37,
            37,
            37,
          ).withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Confirm Delete',
            style: GoogleFonts.ibmPlexMono(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this transaction?',
            style: GoogleFonts.ibmPlexMono(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.ibmPlexMono(
                  color: const Color(0xFF34C759),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                deleteTransaction(transactionId);
              },
              child: Text(
                'Delete',
                style: GoogleFonts.ibmPlexMono(
                  color: const Color(0xFFD33F49),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 700,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ your title row, search bar, filters, and list builder here
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.sync,
                          color: Color(0xFF34C759),
                          size: 24,
                        ),
                        onPressed: () async {
                          await _fadeController.reverse();
                          await fetchTransactions();
                          if (mounted) {
                            await _fadeController.forward();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.ibmPlexMono(color: Colors.white),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Search by name, school ID, or item',
                          hintStyle: GoogleFonts.ibmPlexMono(
                            color: const Color(0xFFA8B0B2),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFFA8B0B2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: _applyFilters,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterValues.asMap().entries.map((entry) {
                        final index = entry.key;
                        final value = entry.value;
                        final label = _filterLabels[index];
                        final isSelected = _selectedFilter == value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = value;
                              });
                              _applyFilters(_searchController.text);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF34C759).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.ibmPlexMono(
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF34C759)
                                      : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height:
                        550 -
                        16 * 2 -
                        14 -
                        12 * 3 -
                        44 -
                        36, // Adjust for title, padding, search bar, filters
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF34C759),
                            ),
                          )
                        : error.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  error,
                                  style: GoogleFonts.ibmPlexMono(
                                    color: const Color(0xFFD33F49),
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () async {
                                    await _fadeController.reverse();
                                    await fetchTransactions();
                                    if (mounted) {
                                      await _fadeController.forward();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF34C759,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Retry',
                                      style: GoogleFonts.ibmPlexMono(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: const Color(0xFF34C759),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : filteredTransactions.isEmpty
                        ? Center(
                            child: Text(
                              "No transactions available",
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = filteredTransactions[index];
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
                              final transactionId = transaction['id'] as String;
                              final displayItemName = items.isNotEmpty
                                  ? items.length > 1
                                        ? "${items[0]['item_name']} (+${items.length - 1})"
                                        : items[0]['item_name'] as String? ??
                                              "Unknown Item"
                                  : "Unknown Item";

                              return GestureDetector(
                                onTap: () => _showItemsDialog(context, items),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      40,
                                      40,
                                      40,
                                    ).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipOval(
                                        child: image != null && image.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: image,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const CircularProgressIndicator(
                                                      color: Color(0xFF34C759),
                                                    ),
                                                errorWidget: (context, url, error) {
                                                  debugPrint(
                                                    "Image load error for URL: $url, error: $error",
                                                  );
                                                  return const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
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
                                                    style:
                                                        GoogleFonts.ibmPlexMono(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    schoolId,
                                                    style:
                                                        GoogleFonts.ibmPlexMono(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                    style:
                                                        GoogleFonts.ibmPlexMono(
                                                          color: Colors.white70,
                                                          fontSize: 10,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    'Due: $returnDate',
                                                    style:
                                                        GoogleFonts.ibmPlexMono(
                                                          color: Colors.white70,
                                                          fontSize: 10,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              displayItemName,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: Colors.white70,
                                                fontSize: 10,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: getStatusColor(
                                                transaction,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Color(0xFFD33F49),
                                              size: 24,
                                            ),
                                            onPressed: () =>
                                                _showDeleteConfirmation(
                                                  context,
                                                  transactionId,
                                                ),
                                          ),
                                        ],
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
