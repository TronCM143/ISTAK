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

class _TransactionsState extends State<TransactionList> {
  static final GlobalKey<_TransactionsState> globalKey =
      GlobalKey<_TransactionsState>();
  List<dynamic> transactions = [];
  bool loading = true;
  String? error;
  int retryCount = 0;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
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
              // Safely handle borrower and item
              final borrower = transaction['borrower'] is Map<String, dynamic>
                  ? transaction['borrower'] as Map<String, dynamic>?
                  : null;
              final item = transaction['item'] is Map<String, dynamic>
                  ? transaction['item'] as Map<String, dynamic>?
                  : null;

              // Log unexpected types for debugging
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
            retryCount = 0; // Reset retry count on success
          });
        }
      } else if (response.statusCode >= 500 && retryCount < maxRetries) {
        retryCount++;
        debugPrint("Server error, retrying ($retryCount/$maxRetries)...");
        await Future.delayed(Duration(seconds: 2 * retryCount));
        return fetchTransactions(); // Retry
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
        return fetchTransactions(); // Retry
      }
      if (mounted) {
        setState(() {
          error = "Error fetching transactions: $e";
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error!,
              style: GoogleFonts.ibmPlexMono(
                color: Colors.redAccent,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w300),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20.0,
          dataRowHeight: 48.0,
          headingRowHeight: 40.0,
          headingTextStyle: GoogleFonts.ibmPlexMono(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          dataTextStyle: GoogleFonts.ibmPlexMono(
            color: Colors.white,
            fontSize: 13,
          ),
          decoration: const BoxDecoration(color: Colors.transparent),
          columns: [
            DataColumn(
              label: Text(
                "Borrow Date",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 121, 107, 70),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Return Date",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 121, 107, 70),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Item Name",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 121, 107, 70),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Borrower Name",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 121, 107, 70),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "School ID",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 121, 107, 70),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Status",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 121, 107, 70),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
          rows: transactions.isEmpty
              ? [
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          "No transactions",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 121, 107, 70),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          "",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 121, 107, 70),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          "",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 121, 107, 70),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          "",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 121, 107, 70),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          "",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 121, 107, 70),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          "",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 121, 107, 70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
              : transactions.map((transaction) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          transaction['borrow_date'] != "N/A"
                              ? DateFormat("MMM d, yyyy").format(
                                  DateTime.parse(transaction['borrow_date']),
                                )
                              : "—",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 237, 205, 174),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['return_date'] != "N/A"
                              ? DateFormat("MMM d, yyyy").format(
                                  DateTime.parse(transaction['return_date']),
                                )
                              : "—",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 237, 205, 174),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['item_name'] as String,
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 237, 205, 174),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['borrower_name'] as String,
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 237, 205, 174),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['school_id'] as String,
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 237, 205, 174),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['status'] as String,
                          style: GoogleFonts.ibmPlexMono(
                            color: transaction['status'] == 'BORROWED'
                                ? Colors.yellow
                                : transaction['status'] == 'RETURNED'
                                ? Colors.green
                                : Colors.redAccent, // Overdue
                            decoration: TextDecoration.none,
                          ),
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
