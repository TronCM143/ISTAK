import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile/components/transaction/borrowing/inputData.dart';
import 'package:mobile/components/transaction/borrowing/scanQRs.dart';
import 'package:mobile/components/transaction/borrowing/processData.dart';
import 'package:mobile/components/transaction/borrowing/sync.dart';

class BorrowScreen extends StatefulWidget {
  const BorrowScreen({Key? key}) : super(key: key);

  @override
  _BorrowScreenState createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  int _currentStep = 0;
  String? _imageUrl;
  Map<String, String>? _borrowerData;
  List<Map<String, dynamic>> _scannedItems = [];
  bool _isScanning = false;

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _imageUrl = null;
      _borrowerData = null;
      _scannedItems = [];
      _isScanning = false;
    });
  }

  void _updateBorrowerData(Map<String, String> data) {
    setState(() {
      _borrowerData = data;
      _imageUrl = data['image_url'];
    });
  }

  void _updateScannedItems(List<Map<String, dynamic>> items) {
    setState(() {
      _scannedItems = items;
      print('📋 Updated scannedItems in BorrowScreen: $_scannedItems');
    });
  }

  void _updateScanningState(bool isScanning) {
    setState(() {
      _isScanning = isScanning;
    });
  }

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncPendingRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(padding: const EdgeInsets.all(16.0), child: _buildStep()),
      backgroundColor: Colors.grey[900],
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return BorrowerInputAndPhoto(
          onDataEntered: _updateBorrowerData,
          onNext: _nextStep,
          onCancel: _reset,
        );
      case 1:
        return ScanItemsQR(
          scannedItems: _scannedItems,
          isScanning: _isScanning,
          onItemsScanned: _updateScannedItems,
          onScanningStateChanged: _updateScanningState,
          onFinish: _nextStep,
        );
      case 2:
        return ProcessTransaction(
          borrowerData: _borrowerData,
          scannedItems: _scannedItems,
          onReset: _reset,
        );
      default:
        return const SizedBox();
    }
  }
}
