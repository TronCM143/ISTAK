import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:mobile/components/transaction/syncTransaction.dart';

class AutoSyncService {
  static Future<void> queueRequest(Map<String, dynamic> request) async {
    await LocalDatabase().saveBorrowRequest(request);
    if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
      // Context is not available here; rely on SyncTransactions.performSync
      await SyncTransactions.performSync(
        request['type'],
        onFeedback: (message, isSuccess) {
          print('AutoSync feedback: $message (success: $isSuccess)');
          // Optionally, use a global event bus or notification system for UI feedback
        },
      );
    }
  }
}
