import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mobile/apiURl.dart'; // Assuming API.baseUrl is defined here

class ForecastWidget extends StatelessWidget {
  const ForecastWidget({super.key});

  // Fetch forecast data from backend
  Future<Map<String, int>> fetchForecastData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");

    if (token == null) {
      throw Exception("No access token found");
    }

    final url = Uri.parse('${API.baseUrl}/api/inventory/');
    final response = await http
        .get(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'available': data['available'] as int? ?? 0,
        'borrowed': data['borrowed'] as int? ?? 0,
        'returningToday': data['returningToday'] as int? ?? 0,
        'overdue': data['overdue'] as int? ?? 0,
      };
    } else {
      throw Exception("Failed to load forecast data: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: fetchForecastData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB300), // Yellow
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: GoogleFonts.ibmPlexMono(
                      color: const Color(0xFFD33F49), // Red
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final forecastData =
            snapshot.data ??
            {'available': 0, 'borrowed': 0, 'returningToday': 0, 'overdue': 0};
        final totalItems = forecastData.values.reduce((a, b) => a + b);
        final borrowedPercentage = totalItems > 0
            ? ((forecastData['borrowed']! / totalItems) * 100).toStringAsFixed(
                0,
              )
            : '0';

        const barTotalWidth = 80.0;
        final availableWidth = totalItems > 0
            ? (forecastData['available']! / totalItems) * barTotalWidth
            : 0.0;
        final borrowedWidth = totalItems > 0
            ? (forecastData['borrowed']! / totalItems) * barTotalWidth
            : 0.0;
        final returningTodayWidth = totalItems > 0
            ? (forecastData['returningToday']! / totalItems) * barTotalWidth
            : 0.0;
        final overdueWidth = totalItems > 0
            ? (forecastData['overdue']! / totalItems) * barTotalWidth
            : 0.0;

        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SIDE (Text content)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY FORECASTS",
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // % Borrowed
                          Text(
                            "$borrowedPercentage%",
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 246, 246, 246),
                            ),
                          ),
                          Text(
                            "borrowed",
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${forecastData['returningToday']} \n: returning today",
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD33F49).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${forecastData['overdue']} Overdue",
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFD33F49),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // RIGHT SIDE (Vertical bar graph)
                    Container(
                      width: 30,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (availableWidth > 0)
                            Flexible(
                              flex: forecastData['available']!,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (borrowedWidth > 0)
                            Flexible(
                              flex: forecastData['borrowed']!,
                              child: Container(color: const Color(0xFFFFB300)),
                            ),
                          if (returningTodayWidth > 0)
                            Flexible(
                              flex: forecastData['returningToday']!,
                              child: Container(color: const Color(0xFFFF9500)),
                            ),
                          if (overdueWidth > 0)
                            Flexible(
                              flex: forecastData['overdue']!,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD33F49),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                ),
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
      },
    );
  }
}
