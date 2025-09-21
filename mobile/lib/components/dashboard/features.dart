import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
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
          error = "Failed to load items: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      // ✅ Custom message for no internet
      setState(() {
        if (e.toString().contains("Failed host lookup") ||
            e.toString().contains("SocketException")) {
          error = "No Internet. Failed to fetch items.";
        } else {
          error = "Error fetching top items: $e";
        }
        loading = false;
      });
    }
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
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // ✅ Normal display when items are loaded
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: topItems.map((item) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child:
                      item['image'] != null &&
                          item['image'].toString().isNotEmpty
                      ? Image.network(
                          item['image'],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 40,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['item_name'] ?? 'N/A',
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color.fromARGB(255, 150, 139, 88),
                    fontSize: 15,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
