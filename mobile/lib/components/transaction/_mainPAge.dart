import 'package:flutter/material.dart';
import 'package:mobile/components/transaction/borrow.dart';
import 'package:mobile/components/transaction/returning.dart';
import 'package:google_fonts/google_fonts.dart';

class SelectTask extends StatelessWidget {
  const SelectTask({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Borrow()),
                );
              },
              child: Container(
                color: const Color(0xFF151107),
                child: Center(
                  child: Text(
                    'Borrow',
                    style: GoogleFonts.ibmPlexMono(
                      color: const Color.fromARGB(255, 148, 148, 147),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReturnItem()),
                );
              },
              child: Container(
                color: const Color(0xFF151107),
                child: Center(
                  child: Text(
                    'Return',
                    style: GoogleFonts.ibmPlexMono(
                      color: const Color.fromARGB(255, 148, 148, 147),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
