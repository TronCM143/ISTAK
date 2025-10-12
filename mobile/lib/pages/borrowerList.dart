import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class Borrowerlist extends StatefulWidget {
  const Borrowerlist({super.key});

  @override
  State<Borrowerlist> createState() => _BorrowerlistState();
}

class _BorrowerlistState extends State<Borrowerlist>
    with TickerProviderStateMixin {
  List<dynamic> borrowers = [];
  String selectedFilter = 'All';
  String searchQuery = '';
  bool loading = true;
  String? error;
  String? accessToken;
  double _scaffoldHeight = 600.0;
  late AnimationController _refreshController;
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
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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

    await fetchBorrowers();
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
          setState(() {
            borrowers = _unifyBorrowers(data);
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
        borrowerMap[key]['borrowed_items'] = [
          ...borrowerMap[key]['borrowed_items'],
          ...(borrower['borrowed_items'] ?? []),
        ].toSet().toList();
        borrowerMap[key]['transaction_count'] =
            (borrowerMap[key]['transaction_count'] ?? 0) +
            (borrower['transaction_count'] ?? 0);
        borrowerMap[key]['total_borrowed_items'] =
            (borrowerMap[key]['total_borrowed_items'] ?? 0) +
            (borrower['total_borrowed_items'] ?? 0);
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

  Widget _buildHeightAdjuster() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Adjust Height: ${_scaffoldHeight.toStringAsFixed(0)}',
            style: GoogleFonts.ibmPlexMono(color: Colors.white, fontSize: 14),
          ),
          Slider(
            value: _scaffoldHeight,
            min: 300.0,
            max: MediaQuery.of(context).size.height,
            divisions: 100,
            label: _scaffoldHeight.toStringAsFixed(0),
            activeColor: const Color(0xFF34C759),
            inactiveColor: Colors.white.withOpacity(0.2),
            onChanged: (value) => setState(() => _scaffoldHeight = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: TextField(
            style: GoogleFonts.ibmPlexMono(color: Colors.white, fontSize: 14),
            textAlignVertical: TextAlignVertical.center,
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
            onChanged: (value) => setState(() => searchQuery = value),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['All', 'Active', 'Inactive'].map((filter) {
          final bool isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => selectedFilter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  color: isSelected
                      ? const Color(0xFF34C759).withOpacity(0.3)
                      : Colors.transparent,
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : const Color(0xFFA8B0B2),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBorrowerList(List<dynamic> filteredBorrowers) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF34C759)),
      );
    }
    if (error != null) {
      return Center(
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
            GestureDetector(
              onTap: _loadTokenAndFetchBorrowers,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (filteredBorrowers.isEmpty) {
      return Center(
        child: Text(
          'No borrowers found',
          style: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w300,
            color: Colors.white,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredBorrowers.length,
      itemBuilder: (context, index) =>
          _buildBorrowerItem(filteredBorrowers[index]),
    );
  }

  Widget _buildBorrowerItem(dynamic borrower) {
    final lastBorrowedDate =
        borrower['last_borrowed_date']?.toString() ?? "None";
    final totalBorrowedItems = borrower['total_borrowed_items'] ?? 0;
    return GestureDetector(
      onTap: () => _showBorrowerTransactions(borrower),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              // 👇 this adds the color overlay
              color: Colors.white.withOpacity(0.08),
              child: ListTile(
                leading: _buildBorrowerAvatar(borrower),
                title: Text(
                  '${borrower['name']}: ${borrower['school_id']}',
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Last Borrowed: $lastBorrowedDate',
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  'Items: $totalBorrowedItems',
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBorrowerAvatar(dynamic borrower) {
    return GestureDetector(
      onTap: borrower['image'] != null
          ? () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: InteractiveViewer(
                      child: Image.network(
                        borrower['image'],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 80,
                                color: Color(0xFFF5F7F5),
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
              backgroundImage: NetworkImage(borrower['image']),
              onBackgroundImageError: (error, stack) => debugPrint(
                "Image load error for ${borrower['image']}: $error",
              ),
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
    );
  }

  void _showBorrowerTransactions(dynamic borrower) async {
    try {
      final transactions = await fetchBorrowerTransactions(borrower['id']);
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Borrowed Items: ${borrower['name']} (${borrower['school_id']})',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.maxFinite,
                        constraints: const BoxConstraints(maxHeight: 400),
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
                                  final transaction = transactions[index];
                                  final items = transaction['items'] ?? [];
                                  final itemNames = items
                                      .map(
                                        (item) =>
                                            item['item_name'] ?? 'Unknown Item',
                                      )
                                      .join(', ');
                                  final borrowDate =
                                      transaction['borrow_date'] != null
                                      ? DateFormat('MMM d, yyyy').format(
                                          DateTime.parse(
                                            transaction['borrow_date'],
                                          ),
                                        )
                                      : 'N/A';
                                  final returnDate =
                                      transaction['return_date'] != null
                                      ? DateFormat('MMM d, yyyy').format(
                                          DateTime.parse(
                                            transaction['return_date'],
                                          ),
                                        )
                                      : 'Not returned';
                                  final status =
                                      transaction['status']?.toString() ??
                                      'Unknown';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 5,
                                          sigmaY: 5,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemNames.isEmpty
                                                    ? 'No items in this transaction'
                                                    : itemNames,
                                                style: GoogleFonts.ibmPlexMono(
                                                  fontWeight: FontWeight.w400,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                'Status: $status\nBorrowed: $borrowDate\nReturned: $returnDate',
                                                style: GoogleFonts.ibmPlexMono(
                                                  fontWeight: FontWeight.w300,
                                                  color: Colors.grey[400],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Close',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF34C759),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('Borrower not found')
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
  }

  @override
  Widget build(BuildContext context) {
    final filteredBorrowers = getFilteredBorrowers();
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth > 700 ? 700.0 : screenWidth * 1;

    return Column(
      children: [
        //  _buildHeightAdjuster(),
        SizedBox(height: 100),
        SizedBox(
          height: _scaffoldHeight,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              width: containerWidth,

              // decoration: BoxDecoration(
              //   color: Colors.white.withOpacity(0.05),
              //   borderRadius: BorderRadius.circular(12),
              //   border: Border.all(
              //     color: Colors.white.withOpacity(0.18),
              //     width: 1,
              //   ),
              // ),
              child: LiquidGlass(
                shape: LiquidRoundedSuperellipse(
                  borderRadius: const Radius.circular(30),
                ),
                settings: const LiquidGlassSettings(
                  thickness: 50, // controls optical depth (refraction)
                  glassColor: Color.fromARGB(
                    26,
                    65,
                    65,
                    65,
                  ), // dark translucent tint
                  lightIntensity: 1.25, // highlight brightness
                  ambientStrength: 0.5, // soft glow
                  saturation: 1.05,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Borrower List',
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
                                  await fetchBorrowers();
                                  if (mounted) {
                                    await _fadeController.forward();
                                    _refreshController.reset();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        _buildFilterButtons(),
                        const SizedBox(height: 16),
                        _buildBorrowerList(filteredBorrowers),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _refreshController.dispose();
    super.dispose();
  }
}
