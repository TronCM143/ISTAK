import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile/components/transaction/borrowing/inputData.dart';
import 'package:mobile/components/transaction/borrowing/processData.dart';
import 'package:mobile/components/transaction/borrowing/scanQRs.dart';
import 'package:mobile/components/transaction/borrowing/sync.dart';
import 'package:mobile/components/transaction/borrowing/takePhoto.dart';

class BorrowScreen extends StatefulWidget {
  const BorrowScreen({Key? key}) : super(key: key);

  @override
  _BorrowScreenState createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  int _currentStep = 0;
  File? _photo;
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
      _photo = null;
      _borrowerData = null;
      _scannedItems = [];
      _isScanning = false;
    });
  }

  void _updatePhoto(File? photo) {
    setState(() {
      _photo = photo;
    });
  }

  void _updateBorrowerData(Map<String, String> data) {
    setState(() {
      _borrowerData = data;
    });
  }

  void _updateScannedItems(List<Map<String, dynamic>> items) {
    setState(() {
      _scannedItems = items;
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
        // Sync logic will be called from ProcessTransaction
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
        return TakePhoto(
          onPhotoTaken: _updatePhoto, // ✅ stores photo in state
          onNext: _nextStep,
        );
      case 1:
        return InputFields(
          photo: _photo, // ✅ pass photo to InputFields
          onPhotoTaken:
              _updatePhoto, // allow retake inside InputFields if needed
          onDataEntered: _updateBorrowerData,
          onNext: _nextStep,
          onCancel: _reset,
        );
      case 2:
        return ScanItemsQR(
          scannedItems: _scannedItems,
          isScanning: _isScanning,
          onItemsScanned: _updateScannedItems,
          onScanningStateChanged: _updateScanningState,
          onFinish: _nextStep,
        );
      case 3:
        return ProcessTransaction(
          photo: _photo,
          borrowerData: _borrowerData,
          scannedItems: _scannedItems,
          onReset: _reset,
        );
      default:
        return const SizedBox();
    }
  }
}
