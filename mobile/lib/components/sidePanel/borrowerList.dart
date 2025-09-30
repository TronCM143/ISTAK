import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile/apiURL.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Borrowers',
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
            items: ['All', 'Active', 'Inactive']
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
            onPressed: fetchBorrowers,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      error!,
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w300,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchBorrowers,
                      child: Text(
                        'Retry',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : borrowers.isEmpty
            ? Center(
                child: Text(
                  'No borrowers found',
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: getFilteredBorrowers().length,
                itemBuilder: (context, index) {
                  final borrower = getFilteredBorrowers()[index];
                  final lastBorrowedDate =
                      borrower['last_borrowed_date']?.toString() ?? "None";
                  final totalBorrowedItems =
                      borrower['total_borrowed_items'] ?? 0;

                  return Card(
                    color: Colors.grey[850],
                    child: ListTile(
                      leading: borrower['image'] != null
                          ? CircleAvatar(
                              radius: 25,
                              backgroundImage: NetworkImage(borrower['image']),
                              onBackgroundImageError: (error, stack) {
                                debugPrint(
                                  "Image load error for ${borrower['image']}: $error",
                                );
                              },
                            )
                          : CircleAvatar(
                              radius: 25,
                              child: Text(
                                borrower['name']?[0] ?? 'B',
                                style: GoogleFonts.ibmPlexMono(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      title: Text(
                        '${borrower['name']}: ${borrower['school_id']}',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Last Borrowed: $lastBorrowedDate',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w300,
                          color: Colors.grey[400],
                        ),
                      ),
                      trailing: Text(
                        'Items: $totalBorrowedItems',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Home()),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      backgroundColor: Colors.grey[900],
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    borrowers = [];
    selectedFilter = 'All';
    loading = true;
    error = null;
    super.dispose();
  }
}
