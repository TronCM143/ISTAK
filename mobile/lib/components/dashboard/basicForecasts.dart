import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ForecastWidget extends StatelessWidget {
  const ForecastWidget({super.key});

  Future<Map<String, int>> fetchForecastData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("access_token");
    if (token == null) throw Exception("No access token found");

    final url = Uri.parse('${dotenv.env['BASE_URL']}/api/inventory/');
    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

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
          return _glassCard(
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB300)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _glassCard(
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexMono(
                  color: const Color(0xFFD33F49),
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        final data =
            snapshot.data ??
            {'available': 0, 'borrowed': 0, 'returningToday': 0, 'overdue': 0};

        final total =
            (data['available']! +
            data['borrowed']! +
            data['returningToday']! +
            data['overdue']!);
        final borrowedPercent = total > 0
            ? ((data['borrowed']! / total) * 100).round()
            : 0;

        return _glassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Side: Text Information
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      "Today Forecast",
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Borrowed Percentage
                    Row(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "$borrowedPercent%",
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.45),
                                  blurRadius: max(
                                    0.0,
                                    8.0,
                                  ), // ✅ guarantees non-negative
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            "Borrowed",
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Returning Items
                    Row(
                      children: [
                        Text(
                          "${data['returningToday']}",
                          style: GoogleFonts.ibmPlexMono(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            "items\nreturning",
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white70,
                              height: 1.0,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Overdue Items
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.black.withOpacity(0.25),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        "${data['overdue']} overdue",
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFD33F49),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Side: Forecast Bar
              _ForecastBar(
                total: total,
                available: data['available']!,
                borrowed: data['borrowed']!,
                returning: data['returningToday']!,
                overdue: data['overdue']!,
                height: 160,
                width: 28,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: 300, // Fixed width
      height: 240, // Fixed height
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _ForecastBar extends StatelessWidget {
  final int total, available, borrowed, returning, overdue;
  final double height;
  final double width;

  const _ForecastBar({
    required this.total,
    required this.available,
    required this.borrowed,
    required this.returning,
    required this.overdue,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = total > 0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasData
            ? Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Background for empty state
                  Container(color: Colors.white.withOpacity(0.06)),
                  // Animated segments
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildSegment(
                        overdue,
                        total,
                        const Color(0xFFD33F49),
                      ), // Red
                      _buildSegment(
                        returning,
                        total,
                        const Color(0xFFFF9500),
                      ), // Orange
                      _buildSegment(
                        borrowed,
                        total,
                        const Color(0xFFFFB300),
                      ), // Yellow
                      _buildSegment(
                        available,
                        total,
                        const Color(0xFF34C759),
                      ), // Green
                    ],
                  ),
                ],
              )
            : Container(color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  Widget _buildSegment(int value, int total, Color color) {
    if (value <= 0) return const SizedBox.shrink(); // Skip zero values
    final proportion = value / total;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: height * proportion,
      color: color,
    );
  }
}
