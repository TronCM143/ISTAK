import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/components/_landing_page.dart';

class Borrowerlist extends StatefulWidget {
  const Borrowerlist({super.key});

  @override
  State<Borrowerlist> createState() => _BorrowerlistState();
}

class _BorrowerlistState extends State<Borrowerlist>
    with SingleTickerProviderStateMixin {
  List<dynamic> borrowers = [];
  String selectedFilter = 'All';
  String searchQuery = '';
  bool loading = true;
  String? error;
  String? accessToken;

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
    _loadTokenAndFetchBorrowers();
  }

  Future<void> _loadTokenAndFetchBorrowers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    if (token == null || token.isEmpty) {
      setState(() {
        error = "No access token found. Please log in again.";
        loading = false;
      });
      return;
    }

    setState(() {
      accessToken = token;
    });

    fetchBorrowers();
  }

  Future<void> fetchBorrowers() async {
    if (accessToken == null || accessToken!.isEmpty) {
      setState(() {
        error = "Please log in to view borrowers";
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final url = Uri.parse('${dotenv.env['BASE_URL']}/api/borrowers/');
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          // Unify duplicate borrowers
          final unifiedBorrowers = _unifyBorrowers(data);
          setState(() {
            borrowers = unifiedBorrowers;
            loading = false;
          });
        } else {
          throw Exception("Invalid response format: Expected a list");
        }
      } else {
        setState(() {
          error =
              "Failed to load borrowers: ${response.statusCode} - ${response.body}";
          loading = false;
        });
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
    }
  }

  List<dynamic> _unifyBorrowers(List<dynamic> rawBorrowers) {
    final Map<String, dynamic> borrowerMap = {};
    for (var borrower in rawBorrowers) {
      final key = '${borrower['name']}_${borrower['school_id']}';
      if (!borrowerMap.containsKey(key)) {
        borrowerMap[key] = {
          'id': borrower['id'],
          'name': borrower['name'],
          'school_id': borrower['school_id'],
          'status': borrower['status'],
          'image': borrower['image'],
          'borrowed_items': borrower['borrowed_items'] ?? [],
          'transaction_count': borrower['transaction_count'] ?? 0,
          'total_borrowed_items': borrower['total_borrowed_items'] ?? 0,
          'last_borrowed_date': borrower['last_borrowed_date'],
        };
      } else {
        // Merge borrowed items and update counts
        borrowerMap[key]['borrowed_items'] = [
          ...borrowerMap[key]['borrowed_items'],
          ...(borrower['borrowed_items'] ?? []),
        ].toSet().toList(); // Remove duplicates
        borrowerMap[key]['transaction_count'] =
            (borrowerMap[key]['transaction_count'] ?? 0) +
            (borrower['transaction_count'] ?? 0);
        borrowerMap[key]['total_borrowed_items'] =
            (borrowerMap[key]['total_borrowed_items'] ?? 0) +
            (borrower['total_borrowed_items'] ?? 0);
        // Use the most recent last_borrowed_date
        final currentDate = borrower['last_borrowed_date'] != null
            ? DateTime.tryParse(borrower['last_borrowed_date'])
            : null;
        final existingDate = borrowerMap[key]['last_borrowed_date'] != null
            ? DateTime.tryParse(borrowerMap[key]['last_borrowed_date'])
            : null;
        if (currentDate != null &&
            (existingDate == null || currentDate.isAfter(existingDate))) {
          borrowerMap[key]['last_borrowed_date'] =
              borrower['last_borrowed_date'];
        }
      }
    }
    return borrowerMap.values.toList();
  }

  Future<List<dynamic>> fetchBorrowerTransactions(int borrowerId) async {
    try {
      final url = Uri.parse(
        '${dotenv.env['BASE_URL']}/api/borrowers/$borrowerId/transactions/',
      );
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      } else if (response.statusCode == 404) {
        throw Exception("Borrower or transactions not found");
      } else {
        throw Exception(
          "Failed to load transactions: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      throw Exception("Unable to load transactions: $e");
    }
  }

  List<dynamic> getFilteredBorrowers() {
    return borrowers.where((borrower) {
      final status = borrower["status"]?.toLowerCase();
      final name = (borrower["name"] as String? ?? "").toLowerCase();
      final schoolId = (borrower["school_id"] as String? ?? "").toLowerCase();
      final query = searchQuery.toLowerCase();
      final matchesSearch = name.contains(query) || schoolId.contains(query);
      if (selectedFilter == 'All') return matchesSearch;
      if (selectedFilter == 'Active')
        return status == 'active' && matchesSearch;
      if (selectedFilter == 'Inactive')
        return status == 'inactive' && matchesSearch;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBorrowers = getFilteredBorrowers();
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchBorrowers,
          ),
        ],
      ),
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
                    hintText: 'Search by name or school ID...',
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
              // Filter Buttons
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
              const SizedBox(height: 16),
              // Borrower List
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF34C759),
                        ),
                      )
                    : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error!,
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFFD33F49),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadTokenAndFetchBorrowers,
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
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredBorrowers.isEmpty
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
                        itemCount: filteredBorrowers.length,
                        itemBuilder: (context, index) {
                          final borrower = filteredBorrowers[index];
                          final lastBorrowedDate =
                              borrower['last_borrowed_date']?.toString() ??
                              "None";
                          final totalBorrowedItems =
                              borrower['total_borrowed_items'] ?? 0;

                          return Card(
                            color: Colors.grey[850],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: GestureDetector(
                                onTap: borrower['image'] != null
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: const EdgeInsets.all(
                                              16,
                                            ),
                                            child: GestureDetector(
                                              onTap: () =>
                                                  Navigator.of(context).pop(),
                                              child: InteractiveViewer(
                                                child: Image.network(
                                                  borrower['image'],
                                                  fit: BoxFit.contain,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Center(
                                                        child: Icon(
                                                          Icons.broken_image,
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
                                      }
                                    : null,
                                child: borrower['image'] != null
                                    ? CircleAvatar(
                                        radius: 25,
                                        backgroundImage: NetworkImage(
                                          borrower['image'],
                                        ),
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
                              onTap: () async {
                                try {
                                  final transactions =
                                      await fetchBorrowerTransactions(
                                        borrower['id'],
                                      );
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.grey[850],
                                      title: Text(
                                        'Borrowed Items: ${borrower['name']} (${borrower['school_id']})',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                      content: Container(
                                        width: double.maxFinite,
                                        constraints: const BoxConstraints(
                                          maxHeight: 400,
                                        ),
                                        child: transactions.isEmpty
                                            ? Text(
                                                'No transactions found for this borrower.',
                                                style: GoogleFonts.ibmPlexMono(
                                                  fontWeight: FontWeight.w300,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: transactions.length,
                                                itemBuilder: (context, index) {
                                                  final transaction =
                                                      transactions[index];
                                                  final items =
                                                      transaction['items'] ??
                                                      [];
                                                  final itemNames = items
                                                      .map(
                                                        (item) =>
                                                            item['item_name'] ??
                                                            'Unknown Item',
                                                      )
                                                      .join(', ');
                                                  final borrowDate =
                                                      transaction['borrow_date'] !=
                                                          null
                                                      ? DateFormat(
                                                          'MMM d, yyyy',
                                                        ).format(
                                                          DateTime.parse(
                                                            transaction['borrow_date'],
                                                          ),
                                                        )
                                                      : 'N/A';
                                                  final returnDate =
                                                      transaction['return_date'] !=
                                                          null
                                                      ? DateFormat(
                                                          'MMM d, yyyy',
                                                        ).format(
                                                          DateTime.parse(
                                                            transaction['return_date'],
                                                          ),
                                                        )
                                                      : 'Not returned';
                                                  final status =
                                                      transaction['status']
                                                          ?.toString() ??
                                                      'Unknown';

                                                  return Card(
                                                    color: Colors.grey[800],
                                                    child: ListTile(
                                                      title: Text(
                                                        itemNames.isEmpty
                                                            ? 'No items in this transaction'
                                                            : itemNames,
                                                        style:
                                                            GoogleFonts.ibmPlexMono(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                      subtitle: Text(
                                                        'Status: $status\nBorrowed: $borrowDate\nReturned: $returnDate',
                                                        style:
                                                            GoogleFonts.ibmPlexMono(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w300,
                                                              color: Colors
                                                                  .grey[400],
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text(
                                            'Close',
                                            style: GoogleFonts.ibmPlexMono(
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF34C759),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().contains(
                                              'Borrower not found',
                                            )
                                            ? 'Borrower or transactions not found'
                                            : 'Failed to load transactions. Please try again.',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontWeight: FontWeight.w300,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFFD33F49),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
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
    searchQuery = '';
    loading = true;
    error = null;
    accessToken = null;
    super.dispose();
  }
}
