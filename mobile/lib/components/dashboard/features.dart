import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/apiURl.dart';

class Features extends StatefulWidget {
  const Features({super.key});

  @override
  State<Features> createState() => _FeaturesState();
}

class _FeaturesState extends State<Features> {
  List<dynamic> topItems = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchTopBorrowedItems();
  }

  Future<void> fetchTopBorrowedItems() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      if (token == null) {
        setState(() {
          error = "User not authenticated";
          loading = false;
        });
        return;
      }

      final url = Uri.parse('${API.baseUrl}/api/top-borrowed-items/');
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            topItems = data;
            loading = false;
          });
        } else {
          throw Exception("Invalid response format: Expected a list");
        }
      } else {
        setState(() {
          error =
              "Failed to load top items: ${response.statusCode} - ${response.body}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error fetching top items: $e";
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
              child: Text(error!, style: const TextStyle(color: Colors.white)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: topItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Display image with error handling
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              item['image'] != null &&
                                  item['image'].toString().isNotEmpty
                              ? Image.network(
                                  item['image'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                      'Image load error for ${item['item_name']}: $error',
                                    );
                                    return Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            progress.cumulativeBytesLoaded /
                                            (progress.expectedTotalBytes ?? 1),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        // Display item name
                        Text(
                          item['item_name'] ?? 'N/A',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
