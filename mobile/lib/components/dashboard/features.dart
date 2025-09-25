import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/apiURl.dart';
import 'package:fl_chart/fl_chart.dart';

class Features extends StatefulWidget {
  const Features({super.key});

  @override
  State<Features> createState() => _FeaturesState();
}

class _FeaturesState extends State<Features>
    with SingleTickerProviderStateMixin {
  int availableCount = 0;
  int borrowedCount = 0;
  bool loading = true;
  String? error;
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
    _fadeController.forward();
    fetchItemStatusCount();
  }

  Future<void> fetchItemStatusCount() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("access_token");

      if (token == null) {
        setState(() {
          error = "Please log in to view analytics";
          loading = false;
        });
        return;
      }

      final url = Uri.parse('${API.baseUrl}/api/item-status-count/');
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> &&
            data.containsKey('available') &&
            data.containsKey('borrowed')) {
          setState(() {
            availableCount = data['available'] ?? 0;
            borrowedCount = data['borrowed'] ?? 0;
            loading = false;
          });
        } else {
          throw Exception(
            "Invalid response format: Expected available and borrowed counts",
          );
        }
      } else {
        setState(() {
          error = "Failed to load analytics: ${response.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains("Failed host lookup") ||
            e.toString().contains("SocketException")) {
          error = "No Internet. Failed to fetch analytics.";
        } else {
          error = "Error fetching analytics: $e";
        }
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10), // 10px margins
        child: Container(
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Status",
                style: GoogleFonts.ibmPlexMono(
                  color: const Color(0xFFF5F7F5), // --card-foreground
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 100,
                      maxHeight: 200, // Fixed height for graph
                    ),
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF34C759), // --primary
                            ),
                          )
                        : error != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                error!,
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color(
                                    0xFFD33F49,
                                  ), // --destructive
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  await _fadeController.reverse();
                                  await fetchItemStatusCount();
                                  if (mounted) {
                                    await _fadeController.forward();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFF34C759,
                                  ), // --primary
                                  foregroundColor: const Color(
                                    0xFF1A3C34,
                                  ), // --primary-foreground
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  elevation: 2,
                                  shadowColor: Colors.black.withOpacity(0.2),
                                ),
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: const Color(
                                      0xFF1A3C34,
                                    ), // --primary-foreground
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 150,
                                width: constraints.maxWidth,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY:
                                        (availableCount + borrowedCount)
                                                .toDouble() >
                                            0
                                        ? (availableCount + borrowedCount)
                                                  .toDouble() *
                                              1.2
                                        : 10,
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipItem:
                                            (group, groupIndex, rod, rodIndex) {
                                              final title = group.x == 0
                                                  ? 'Available'
                                                  : 'Borrowed';
                                              return BarTooltipItem(
                                                '$title\n${rod.toY.toInt()}',
                                                GoogleFonts.ibmPlexMono(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final title = value == 0
                                                ? 'Available'
                                                : 'Borrowed';
                                            return Text(
                                              title,
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 14,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: GoogleFonts.ibmPlexMono(
                                                color: const Color(0xFFF5F7F5),
                                                fontSize: 12,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: const FlGridData(show: false),
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [
                                          BarChartRodData(
                                            toY: availableCount.toDouble(),
                                            color: const Color(
                                              0xFF2196F3,
                                            ), // Blue
                                            width: constraints.maxWidth / 4,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [
                                          BarChartRodData(
                                            toY: borrowedCount.toDouble(),
                                            color: const Color(
                                              0xFFFFB300,
                                            ), // Yellow
                                            width: constraints.maxWidth / 4,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Legend
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2196F3), // Blue
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Available',
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFB300), // Yellow
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Borrowed',
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}
