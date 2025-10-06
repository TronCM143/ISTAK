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
            context,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB300)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _glassCard(
            context,
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
          context,
          child: LayoutBuilder(
            builder: (context, c) {
              // Scale typography to card height to avoid overflow
              final h = c.maxHeight;
              final scale = (h / 240).clamp(0.8, 1.4);

              return Row(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT SIDE
                  Expanded(
                    child: Column(
                      //      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title centered like the reference
                        Center(
                          child: Text(
                            "Today Forecast",
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white70,
                              fontSize: 14 * scale,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Big % + label
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$borrowedPercent%",
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white,
                                fontSize: 56 * scale,
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
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                "Borrowed",
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white70,
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // "5 items returning" styling like the image
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${data['returningToday']}",
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white,
                                fontSize: 28 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                "items\nreturning",
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white70,
                                  height: 1.0,
                                  fontSize: 12 * scale,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Red pill "2 overdues" with depth
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12 * scale,
                            vertical: 6 * scale,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
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
                            "${data['overdue']} overdues",
                            style: GoogleFonts.ibmPlexMono(
                              color: const Color(0xFFD33F49),
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // RIGHT SIDE: vertical bar in a rounded track
                  SizedBox(width: 18),
                  _ForecastBar(
                    total: total,
                    available: data['available']!,
                    borrowed: data['borrowed']!,
                    returning: data['returningToday']!,
                    overdue: data['overdue']!,
                    height: 160 * scale,
                    width: 32,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Bigger, responsive glass card to avoid overflow
  Widget _glassCard(BuildContext context, {required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 240, minWidth: 260),
      child: Container(
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded track with stacked segments (green, yellow, orange, red)
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
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _seg(available, const Color(0xFF34C759)), // green
                  _seg(borrowed, const Color(0xFFFFB300)), // yellow
                  _seg(returning, const Color(0xFFFF9500)), // orange
                  _seg(overdue, const Color(0xFFD33F49)), // red
                ],
              )
            : Container(color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  Widget _seg(int value, Color color) {
    // Avoid Flex exception when value is 0 by returning a 1px spacer
    if (value <= 0) {
      return const SizedBox(height: 1); // keeps edges smooth
    }
    return Flexible(child: Container(color: color));
  }
}
