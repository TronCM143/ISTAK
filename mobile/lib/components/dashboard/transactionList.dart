import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile/apiURl.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionList extends StatefulWidget {
  const TransactionList({super.key});

  @override
  State<TransactionList> createState() => _TransactionsState();
}

class _TransactionsState extends State<TransactionList>
    with SingleTickerProviderStateMixin {
  static final GlobalKey<_TransactionsState> globalKey =
      GlobalKey<_TransactionsState>();
  List<dynamic> transactions = [];
  bool loading = true;
  String error = "";
  int retryCount = 0;
  static const int maxRetries = 3;
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
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      debugPrint("Fetching transactions - Token: $token");

      if (token == null) {
        setState(() {
          error = "Please log in to view transactions";
          loading = false;
        });
        debugPrint("Authentication failed: $error");
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
      debugPrint("Response body: ${response.body}");

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
              final item = transaction['item'] is Map<String, dynamic>
                  ? transaction['item'] as Map<String, dynamic>?
                  : null;

              if (transaction['borrower'] is! Map<String, dynamic>?) {
                debugPrint(
                  "Unexpected borrower type: ${transaction['borrower'].runtimeType}, value: ${transaction['borrower']}",
                );
              }
              if (transaction['item'] is! Map<String, dynamic>?) {
                debugPrint(
                  "Unexpected item type: ${transaction['item'].runtimeType}, value: ${transaction['item']}",
                );
              }

              return {
                'return_date': (transaction['return_date'] as String?) ?? "N/A",
                'borrow_date': (transaction['borrow_date'] as String?) ?? "N/A",
                'item_name': item != null
                    ? (item['item_name'] as String?) ?? "Unknown Item"
                    : transaction['item'] is String
                    ? transaction['item'] as String
                    : "Unknown Item",
                'borrower_name': borrower != null
                    ? (borrower['name'] as String?) ?? "Unknown"
                    : transaction['borrower'] is String
                    ? transaction['borrower'] as String
                    : "Unknown",
                'school_id': borrower != null
                    ? (borrower['school_id'] as String?) ?? "N/A"
                    : transaction['borrower'] is String
                    ? "N/A"
                    : "N/A",
                'status':
                    (transaction['status'] as String?)?.toUpperCase() ??
                    "UNKNOWN",
              };
            }).toList();
            loading = false;
            retryCount = 0;
          });
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
  }

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'BORROWED':
        return const Color(0xFFFFB300); // Yellow
      case 'RETURNED':
        return const Color(0xFF34C759); // --primary (green)
      default:
        return const Color(0xFFA8B0B2); // --muted-foreground
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          color: Colors.transparent, // Transparent background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // 10px rounded corners
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Transactions",
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFFF5F7F5), // --card-foreground
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
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
                          await fetchTransactions();
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
                // Table
                else
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      children: [
                        // Wrap the whole table in horizontal scroll
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
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
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        "Status",
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        "Borrow Date",
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        "Return Date",
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
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
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        "Borrower Name",
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
                                height:
                                    300, // Fixed height for scrollable table
                                child: ListView.builder(
                                  itemCount: transactions.isEmpty
                                      ? 1
                                      : transactions.length,
                                  itemBuilder: (context, index) {
                                    if (transactions.isEmpty) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                "No transactions",
                                                style: GoogleFonts.ibmPlexMono(
                                                  color: const Color(
                                                    0xFFA8B0B2,
                                                  ),
                                                  fontSize: 14,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 120),
                                            const SizedBox(width: 120),
                                            const SizedBox(width: 150),
                                            const SizedBox(width: 150),
                                          ],
                                        ),
                                      );
                                    }

                                    final transaction = transactions[index];
                                    final status =
                                        transaction['status'] as String;
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
                                    final itemName =
                                        transaction['item_name'] as String;
                                    final borrowerName =
                                        transaction['borrower_name'] as String;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: getStatusColor(status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              status,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: getStatusColor(status),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              borrowDate,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              returnDate,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              itemName,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              borrowerName,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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
