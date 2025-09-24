import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = p.join(await getDatabasesPath(), 'borrow_requests.db');
    return await openDatabase(
      path,
      version: 5, // NEW: Incremented for new table
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE borrow_requests (
            id TEXT PRIMARY KEY,
            type TEXT,
            item_id TEXT,
            borrower_name TEXT,
            school_id TEXT,
            return_date TEXT,
            borrow_date TEXT,
            condition TEXT,
            is_synced INTEGER,
            status TEXT
          )
        ''');
        // NEW: Table for completed transactions
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            item_id TEXT,
            item_name TEXT,
            borrower_name TEXT,
            school_id TEXT,
            borrow_date TEXT,
            return_date TEXT,
            condition TEXT,
            status TEXT,
            is_synced INTEGER
          )
        ''');
        // NEW: Table for item details
        await db.execute('''
          CREATE TABLE items (
            id TEXT PRIMARY KEY,
            item_name TEXT,
            condition TEXT,
            current_transaction_id TEXT,
            current_transaction_borrow_date TEXT,
            current_transaction_borrower_name TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE borrow_requests ADD COLUMN status TEXT',
          );
          await db.execute(
            'UPDATE borrow_requests SET status = CASE WHEN is_synced = 1 THEN "borrowed" ELSE "pending" END',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE borrow_requests ADD COLUMN borrow_date TEXT',
          );
          await db.execute('UPDATE borrow_requests SET borrow_date = ?', [
            DateTime.now().toIso8601String().split('T')[0],
          ]);
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE borrow_requests ADD COLUMN type TEXT');
          await db.execute(
            'ALTER TABLE borrow_requests ADD COLUMN condition TEXT',
          );
          await db.execute('UPDATE borrow_requests SET type = "borrow"');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              item_id TEXT,
              item_name TEXT,
              borrower_name TEXT,
              school_id TEXT,
              borrow_date TEXT,
              return_date TEXT,
              condition TEXT,
              status TEXT,
              is_synced INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE items (
              id TEXT PRIMARY KEY,
              item_name TEXT,
              condition TEXT,
              current_transaction_id TEXT,
              current_transaction_borrow_date TEXT,
              current_transaction_borrower_name TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> saveBorrowRequest(Map<String, dynamic> request) async {
    final db = await database;
    await db.insert('borrow_requests', {
      'id': request['id'],
      'type': request['type'] ?? 'borrow',
      'item_id': request['item_id'],
      'borrower_name': request['borrower_name'],
      'school_id': request['school_id'],
      'return_date': request['return_date'],
      'borrow_date': request['borrow_date'],
      'condition': request['condition'],
      'is_synced': request['is_synced'] == '1' ? 1 : 0,
      'status': request['status'] ?? 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingRequests({
    String type = 'borrow',
  }) async {
    final db = await database;
    return await db.query(
      'borrow_requests',
      where: 'is_synced = ? AND status = ? AND type = ?',
      whereArgs: [0, 'pending', type],
    );
  }

  Future<void> deleteBorrowRequest(String requestId) async {
    final db = await database;
    await db.delete('borrow_requests', where: 'id = ?', whereArgs: [requestId]);
  }

  // NEW: Save item details for offline use
  Future<void> saveItemDetails(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('items', {
      'id': item['id'].toString(),
      'item_name': item['item_name'],
      'condition': item['condition'],
      'current_transaction_id': item['current_transaction']?['id']?.toString(),
      'current_transaction_borrow_date':
          item['current_transaction']?['borrow_date'],
      'current_transaction_borrower_name':
          item['current_transaction']?['borrower_name'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // NEW: Get item details for offline use
  Future<Map<String, dynamic>?> getItemDetails(String itemId) async {
    final db = await database;
    final results = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    if (results.isEmpty) return null;
    final item = results.first;
    return {
      'id': item['id'],
      'item_name': item['item_name'],
      'condition': item['condition'],
      'current_transaction': item['current_transaction_id'] != null
          ? {
              'id': item['current_transaction_id'],
              'borrow_date': item['current_transaction_borrow_date'],
              'borrower_name': item['current_transaction_borrower_name'],
            }
          : null,
    };
  }

  // NEW: Get transaction by item ID for offline borrow check
  Future<Map<String, dynamic>?> getTransactionByItemId(String itemId) async {
    final db = await database;
    final results = await db.query(
      'borrow_requests',
      where: 'item_id = ? AND status = ? AND return_date IS NULL',
      whereArgs: [itemId, 'borrowed'],
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  // NEW: Save completed transaction for printable table
  Future<void> saveTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    await db.insert('transactions', {
      'id': transaction['id'],
      'item_id': transaction['item_id'],
      'item_name': transaction['item_name'],
      'borrower_name': transaction['borrower_name'],
      'school_id': transaction['school_id'],
      'borrow_date': transaction['borrow_date'],
      'return_date': transaction['return_date'],
      'condition': transaction['condition'],
      'status': transaction['status'],
      'is_synced': transaction['is_synced'] == '1' ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // NEW: Get all transactions for printable table
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return await db.query('transactions');
  }
}
