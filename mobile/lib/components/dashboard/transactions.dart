import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile/apiURl.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Transactions extends StatefulWidget {
  const Transactions({super.key});

  @override
  State<Transactions> createState() => _BorrowerState();
}

class _BorrowerState extends State<Transactions> {
  List<dynamic> transactions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null; // Reset error on new fetch attempt
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      debugPrint("Fetching transactions - Token: $token");

      if (token == null) {
        if (mounted)
          setState(() {
            error = "User not authenticated";
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
        final data = jsonDecode(response.body);
        if (data is! List) {
          throw Exception("Invalid response format: Expected a list");
        }
        final userTransactions = data; // Backend filters by mobile_user

        if (mounted)
          setState(() {
            transactions = userTransactions.map((transaction) {
              final borrower = transaction['borrower'] as Map<String, dynamic>?;
              final item = transaction['item'] as Map<String, dynamic>?;
              return {
                'return_date': (transaction['return_date'] as String?) ?? "N/A",
                'item_name': (item?['item_name'] as String?) ?? "N/A",
                'borrower_name': (borrower?['name'] as String?) ?? "N/A",
                'school_id': (borrower?['school_id'] as String?) ?? "N/A",
              };
            }).toList();
            loading = false;
          });
      } else {
        if (mounted)
          setState(() {
            error =
                "Failed to load transactions: ${response.statusCode} - ${response.body}";
            loading = false;
          });
        debugPrint("API error: $error");
      }
    } catch (e, stackTrace) {
      debugPrint("Exception caught: $e, Stack trace: $stackTrace");
      if (mounted)
        setState(() {
          error = "Error fetching transactions: $e";
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(
                error!,
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24.0,
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
                      "Return Date",
                      style: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 121, 107, 70),
                        fontSize: 15,
                        decoration: TextDecoration.none, // ✅ No underline
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Item Name",
                      style: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 121, 107, 70),
                        fontSize: 15,
                        decoration: TextDecoration.none, // ✅ No underline
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Borrower Name",
                      style: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 121, 107, 70),
                        fontSize: 15,
                        decoration: TextDecoration.none, // ✅ No underline
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "School ID",
                      style: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 121, 107, 70),
                        fontSize: 15,
                        decoration: TextDecoration.none, // ✅ No underline
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
                                  color: const Color.fromARGB(
                                    255,
                                    121,
                                    107,
                                    70,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "",
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    121,
                                    107,
                                    70,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "",
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    121,
                                    107,
                                    70,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "",
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    121,
                                    107,
                                    70,
                                  ),
                                  decoration: TextDecoration.none,
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
                                transaction['return_date'] != null
                                    ? DateFormat("MMM. d, yyyy").format(
                                        DateTime.parse(
                                          transaction['return_date'],
                                        ),
                                      )
                                    : "—", // fallback if null
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    237,
                                    205,
                                    174,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                transaction['item_name'] as String,
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    237,
                                    205,
                                    174,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                transaction['borrower_name'] as String,
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    237,
                                    205,
                                    174,
                                  ),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                transaction['school_id'] as String,
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    237,
                                    205,
                                    174,
                                  ),
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
