// import 'package:flutter/material.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:mobile/components/transaction/borrowing/inputData.dart';
// import 'package:mobile/components/transaction/borrowing/scanQRs.dart';
// import 'package:mobile/components/transaction/borrowing/processData.dart';
// import 'package:mobile/components/transaction/borrowing/sync.dart';

// class BorrowScreen extends StatefulWidget {
//   const BorrowScreen({Key? key}) : super(key: key);

//   @override
//   State<BorrowScreen> createState() => _BorrowScreenState();
// }

// class _BorrowScreenState extends State<BorrowScreen> {
//   int _currentStep = 0;
//   Map<String, String>? _borrowerData;
//   Set<String> _scannedItemIds = {}; // simpler, matches your scanner type

//   @override
//   void initState() {
//     super.initState();
//     // Auto-sync pending requests when internet reconnects
//     Connectivity().onConnectivityChanged.listen((result) async {
//       if (result != ConnectivityResult.none) {
//         debugPrint("📶 Internet reconnected — syncing pending requests...");
//         await syncPendingRequests();
//       } else {
//         debugPrint("⚠️ Offline mode — will store borrow data locally.");
//       }
//     });
//   }

//   void _nextStep() {
//     if (!mounted) return;
//     setState(() => _currentStep++);
//   }

//   void _reset() {
//     if (!mounted) return;
//     setState(() {
//       _currentStep = 0;
//       _borrowerData = null;
//       _scannedItemIds.clear();
//     });
//   }

//   void _updateBorrowerData(Map<String, String> data) {
//     if (!mounted) return;
//     setState(() => _borrowerData = data);
//   }

//   void _updateScannedItems(Set<String> newItems) {
//     if (!mounted) return;
//     setState(() {
//       _scannedItemIds = newItems;
//       debugPrint("📦 Scanned Items Updated: $_scannedItemIds");
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[900],
//       body: SafeArea(
//         child: AnimatedSwitcher(
//           duration: const Duration(milliseconds: 400),
//           transitionBuilder: (child, animation) => SlideTransition(
//             position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
//                 .animate(
//                   CurvedAnimation(parent: animation, curve: Curves.easeInOut),
//                 ),
//             child: child,
//           ),
//           child: Padding(
//             key: ValueKey<int>(_currentStep),
//             padding: const EdgeInsets.all(16.0),
//             child: _buildStep(),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStep() {
//     switch (_currentStep) {
//       case 0:
//         // Step 1: Borrower input
//         return BorrowerInputAndPhoto(
//           onDataEntered: _updateBorrowerData,
//           onNext: _nextStep,
//           onCancel: _reset,
//         );

//       case 1:
//         // Step 2: Scan items — simplified QR dialog logic
//         return QRScannerDialog(
//           allowMultiple: true,
//           initial: _scannedItemIds,
//           onItemsScanned: _updateScannedItems, // ✅ updates scanned IDs
//           onFinish: _nextStep, // ✅ goes to process step
//         );

//       case 2:
//         // Step 3: Process transaction — backend/offline handled in processData.dart
//         return ProcessTransaction(
//           borrowerData: _borrowerData,
//           scannedItems: _scannedItemIds.map((id) => {'item_id': id}).toList(),
//           onReset: _reset,
//         );

//       default:
//         return const SizedBox();
//     }
//   }
// }
