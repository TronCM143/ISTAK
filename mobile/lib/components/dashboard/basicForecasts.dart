import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
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
      print('Raw API response: ${response.body}'); // Debug: Remove later
      return {
        'available':
            data['returnedTransactions'] as int? ?? 0, // Map to backend key
        'borrowed':
            data['borrowedTransactions'] as int? ??
            0, // Active borrowed (total for %)
        'returningToday': data['returningTodayTransactions'] as int? ?? 0,
        'overdue': data['overdueTransactions'] as int? ?? 0,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double kBarWidth = 28;
              const double kBarHeight = 160;
              const double kBarGap = 16;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // LEFT CONTENT with padding to keep clear of the right bar and title
                  Padding(
                    padding: const EdgeInsets.only(
                      right: kBarWidth + kBarGap, // reserve space for bar
                      top: 34, // leave room for the top-center title
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Big %
                        SizedBox(
                          height: 90,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "$borrowedPercent%",
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white,
                                fontSize: 80,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Returning row + Overdue layered (overdue on top)
                        SizedBox(
                          height: 56,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Returning row (shifted right by 5px, bigger)
                              Positioned(
                                top: -20,
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      left: 5,
                                      // bottom: ,
                                    ), // +5px
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${data['returningToday']}",
                                          style: GoogleFonts.ibmPlexMono(
                                            color: Colors.white,
                                            fontSize: 32, // bigger
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              //    SizedBox(height: ,),
                              Positioned(
                                top: -5,
                                right: 40,
                                child: Text(
                                  "items\nreturning",
                                  style: GoogleFonts.ibmPlexMono(
                                    color: Colors.white70,
                                    height: 1.0,
                                    fontSize: 16, // bigger
                                  ),
                                ),
                              ),
                              // Overdue badge (bigger + IN FRONT of returning row)
                              Positioned(
                                bottom: -5,
                                left: 7,

                                child: Container(
                                  // padding: const EdgeInsets.symmetric(
                                  //   horizontal: 12,
                                  //   vertical: 6,
                                  // ),
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
                                      fontSize: 25, // bigger
                                      fontWeight: FontWeight.w700,
                                      wordSpacing: -2,
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

                  // TOP-CENTER TITLE
                  Positioned(
                    //     top: ,
                    left: 0,
                    right: 0,
                    bottom: 180,
                    child: Center(
                      child: Text(
                        "Today Forecast",
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color.fromARGB(179, 255, 255, 255),
                          fontSize: 20,
                          letterSpacing: 0.6,
                          wordSpacing: .4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  // RIGHT FORECAST BAR – drawn LAST so it's IN FRONT of everything
                  Positioned(
                    right: 0,
                    top: (constraints.maxHeight - kBarHeight) / 1,
                    child: _ForecastBar(
                      total: total,
                      available: data['available']!,
                      borrowed: data['borrowed']!,
                      returning: data['returningToday']!,
                      overdue: data['overdue']!,
                      height: kBarHeight,
                      width: kBarWidth,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(
          borderRadius: const Radius.circular(30),
        ),
        settings: const LiquidGlassSettings(
          blur: 5,
          thickness: 50, // controls optical depth (refraction)
          glassColor: Color.fromARGB(26, 65, 65, 65), // dark translucent tint
          lightIntensity: 1.25, // highlight brightness
          ambientStrength: 0.5, // soft glow
          saturation: 1.05,
        ),
        child: Container(
          width: 300,
          height: 240,
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
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
