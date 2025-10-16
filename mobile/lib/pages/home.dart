import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile/components/dashboard/basicForecasts.dart';
import 'package:mobile/components/dashboard/transactionList.dart';
import 'package:mobile/components/transaction/borrowing/inputData.dart';
import 'package:mobile/components/transaction/returning/returning.dart';
import 'package:flutter/cupertino.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _lottieController;
  final double qrAnimationSize = 100;
  final double top30 = 100;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _showSuccessDialog(String borrowerName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/done.json',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'Success saving transaction',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                borrowerName,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.lightBlueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 3),
      ),
    );
    if (TransactionList.globalKey.currentState != null) {
      await TransactionList.globalKey.currentState!.fetchTransactions();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: top30),
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                Column(
                  children: [
                    SizedBox(
                      child: _AppleGlassCard(
                        padding: const EdgeInsets.all(1),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: const Color.fromARGB(0, 255, 0, 0),
                            builder: (_) {
                              return Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(
                                      context,
                                    ).viewInsets.bottom,
                                    left: 16,
                                    right: 16,
                                    top: 24,
                                  ),
                                  child: BorrowerInputAndPhoto(
                                    onSuccess: _showSuccessDialog,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Center(
                          child: Icon(
                            Icons.qr_code_scanner,
                            size: qrAnimationSize,
                            color: const Color.fromARGB(255, 248, 248, 248),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReturnItem()),
                        );
                      },
                      child: LiquidGlass(
                        settings: const LiquidGlassSettings(
                          thickness: 40, // High thickness for glass effect
                        ),
                        shape: LiquidRoundedSuperellipse(
                          borderRadius: Radius.circular(23),
                        ),

                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Center(
                                  child: Text(
                                    'Return',
                                    style: DefaultTextStyle.of(context).style
                                        .copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                          decoration: TextDecoration.none,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ForecastWidget(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 560, child: TransactionList()),
      ],
    );
  }
}

class _AppleGlassCard extends StatelessWidget {
  const _AppleGlassCard({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(4),
    this.onTap,
  });

  final Widget child;
  final double? height;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    final cardCore = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // Positioned.fill(
          //   child: BackdropFilter(
          //     filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          //     child: const SizedBox.expand(),
          //   ),
          // ),
          LiquidGlass(
            settings: LiquidGlassSettings(
              thickness: 50,
              glassColor: Color.fromARGB(31, 38, 38, 38),
            ),
            shape: LiquidRoundedSuperellipse(
              borderRadius: const Radius.circular(24),
            ),
            child: Container(
              height: 170,
              width: 170,
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? cardCore
        : GestureDetector(onTap: onTap, child: cardCore);
  }
}
