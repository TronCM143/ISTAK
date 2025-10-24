import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      debugPrint('Raw API response: ${response.body}');
      return {
        'available': data['returnedTransactions'] as int? ?? 0,
        'borrowed': data['borrowedTransactions'] as int? ?? 0,
        'nonOverdueBorrowed':
            data['nonOverdueBorrowedTransactions'] as int? ?? 0,
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
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB300)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _glassCard(
            Center(
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
            {
              'available': 0,
              'borrowed': 0,
              'nonOverdueBorrowed': 0,
              'returningToday': 0,
              'overdue': 0,
            };

        final total = data['available']! + data['borrowed']!;
        final borrowedPercent = total > 0
            ? ((data['borrowed']! / total) * 100).round()
            : 0;

        return _glassCard(
          LayoutBuilder(
            builder: (context, constraints) {
              const double kBarWidth = 28;
              const double kBarHeight = 160;
              const double kBarGap = 16;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // LEFT CONTENT
                  Padding(
                    padding: const EdgeInsets.only(
                      right: kBarWidth + kBarGap,
                      top: 10,
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
                        const SizedBox(height: 6),
                        // Returning & Overdue section
                        SizedBox(
                          height: 56,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: -10,
                                left: 4,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${data['returningToday']} today",
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: -5,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.35),
                                        Colors.black.withOpacity(0.25),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
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

                  // TITLE
                  // Positioned(
                  //   left: 0,
                  //   right: 0,
                  //   bottom: 170,
                  //   child: Center(
                  //     child: Text(
                  //       "Basic Analytics",
                  //       style: GoogleFonts.ibmPlexMono(
                  //         color: Colors.white70,
                  //         fontSize: 20,
                  //         letterSpacing: 0.6,
                  //         fontWeight: FontWeight.w900,
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  // RIGHT BAR
                  Positioned(
                    right: 0,
                    bottom: 20,
                    child: _ForecastBar(
                      total: total,
                      available: data['available']!,
                      nonOverdueBorrowed: data['nonOverdueBorrowed']!,
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

  Widget _glassCard(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(
          borderRadius: const Radius.circular(30),
        ),
        settings: const LiquidGlassSettings(
          blur: 5,
          thickness: 50,
          glassColor: Color.fromARGB(26, 65, 65, 65),
          lightIntensity: 1.25,
          ambientStrength: 0.5,
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

// Forecast bar visualization
class _ForecastBar extends StatelessWidget {
  final int total, available, nonOverdueBorrowed, overdue;
  final double height;
  final double width;

  const _ForecastBar({
    required this.total,
    required this.available,
    required this.nonOverdueBorrowed,
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
                  Container(color: Colors.white.withOpacity(0.06)),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildSegment(overdue, total, const Color(0xFFD33F49)),
                      _buildSegment(
                        nonOverdueBorrowed,
                        total,
                        const Color(0xFFFFB300),
                      ),
                      _buildSegment(available, total, const Color(0xFF34C759)),
                    ],
                  ),
                ],
              )
            : Container(color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  Widget _buildSegment(int value, int total, Color color) {
    if (value <= 0) return const SizedBox.shrink();
    final proportion = value / total;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: height * proportion,
      color: color,
    );
  }
}
