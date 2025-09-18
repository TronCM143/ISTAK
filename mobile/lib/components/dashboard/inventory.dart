import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class Inventory extends StatelessWidget {
  final List items;
  final String selectedFilter;

  const Inventory({
    super.key,
    required this.items,
    required this.selectedFilter,
  });

  List<dynamic> getFilteredItems() {
    final now = DateTime.now();
    return items.where((item) {
      final status = item["status"]?.toLowerCase();
      final lastBorrowed = item["last_borrowed"] != null
          ? DateTime.parse(item["last_borrowed"])
          : null;
      bool isOverdue =
          lastBorrowed != null &&
          lastBorrowed.isBefore(now.subtract(const Duration(days: 7)));

      if (selectedFilter == 'All') return true;
      if (selectedFilter == 'Available') return status == 'available';
      if (selectedFilter == 'Borrowed') return status == 'borrowed';
      if (selectedFilter == 'Overdues') return isOverdue;
      return false;
    }).toList();
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'borrowed':
        return Colors.yellow;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "N/A";
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsedDate);
    } catch (e) {
      return "N/A";
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = getFilteredItems();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: screenWidth - 40),
          child: DataTable(
            showBottomBorder: false,
            dividerThickness: 0, // no row dividers
            headingRowHeight: 0, // remove header titles
            dataRowColor: WidgetStateProperty.all(Colors.transparent),
            columnSpacing: 24.0,
            dataRowHeight: 60.0,
            headingRowColor: WidgetStateProperty.all(Colors.transparent),
            headingTextStyle: GoogleFonts.ibmPlexMono(
              color: Colors.white,
              decoration: TextDecoration.none,
              fontSize: 14,
            ),
            dataTextStyle: GoogleFonts.ibmPlexMono(
              color: Colors.white,
              decoration: TextDecoration.none,
              fontSize: 13,
            ),
            columns: const [
              DataColumn(label: Text("")),
              DataColumn(label: Text("")),
              DataColumn(label: Text("")),
              DataColumn(label: Text("")),
            ],
            rows: filteredItems.map((item) {
              final String? imageUrl = item["image"];
              final String? status = item["status"];
              final String? lastBorrowed = item["last_borrowed"];
              final String? condition = item["condition"]; // Added condition
              final bool isOverdue = lastBorrowed != null
                  ? DateTime.parse(
                      lastBorrowed,
                    ).isBefore(DateTime.now().subtract(const Duration(days: 7)))
                  : false;

              return DataRow(
                color: WidgetStateProperty.all(Colors.transparent),
                cells: [
                  DataCell(
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getStatusColor(isOverdue ? 'overdue' : status),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item["item_name"] ?? "N/A",
                      style: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 158, 144, 106),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      condition ??
                          "N/A", // Changed from _formatDate(lastBorrowed)
                      style: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 158, 144, 106),
                      ),
                    ),
                  ),
                  DataCell(
                    imageUrl != null && imageUrl.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _showImagePreview(context, imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                imageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.broken_image,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.image_not_supported,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
