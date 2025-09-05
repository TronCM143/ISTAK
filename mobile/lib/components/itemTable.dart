import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ItemTable extends StatelessWidget {
  final List items;
  final bool loading;
  final String? error;

  const ItemTable({
    super.key,
    required this.items,
    required this.loading,
    this.error,
  });

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
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Text(
          "No items found",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          dataRowHeight: 80, // increased for image row
          headingRowHeight: 64,
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          dataTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          columns: const [
            DataColumn(label: Text("#")),
            DataColumn(label: Text("Image")),
            DataColumn(label: Text("Name")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("Condition")),
            DataColumn(label: Text("Last Borrowed")),
          ],
          rows: items.asMap().entries.map((entry) {
            final int index = entry.key;
            final dynamic item = entry.value;
            final String? imageUrl =
                item["image"]; // assumes backend provides `image` field

            return DataRow(
              color: MaterialStateProperty.resolveWith<Color?>((
                Set<MaterialState> states,
              ) {
                if (index % 2 == 0) {
                  return Colors.white.withOpacity(0.05);
                }
                return Colors.white.withOpacity(0.02);
              }),
              cells: [
                DataCell(Text(item["id"].toString())),
                DataCell(
                  imageUrl != null && imageUrl.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _showImagePreview(context, imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.white70,
                                  ),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          color: Colors.white70,
                        ),
                ),
                DataCell(Text(item["item_name"] ?? "N/A")),
                DataCell(
                  Text(
                    item["status"] ?? "N/A",
                    style: TextStyle(
                      color: item["status"] == "available"
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                ),
                DataCell(Text(item["condition"] ?? "N/A")),
                DataCell(Text(_formatDate(item["last_borrowed"]))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
