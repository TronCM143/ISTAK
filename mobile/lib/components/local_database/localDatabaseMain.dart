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
      version: 4, // Incremented version for schema update
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE borrow_requests (
            id TEXT PRIMARY KEY,
            type TEXT, -- "borrow" or "return"
            item_id TEXT,
            borrower_name TEXT,
            school_id TEXT,
            return_date TEXT,
            borrow_date TEXT,
            condition TEXT, -- Nullable, for return requests
            is_synced INTEGER,
            status TEXT
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
          await db.execute(
            'UPDATE borrow_requests SET type = "borrow"',
          ); // Existing requests are borrows
        }
      },
    );
  }

  Future<void> saveBorrowRequest(Map<String, dynamic> request) async {
    final db = await database;
    await db.insert('borrow_requests', {
      'id': request['id'],
      'type':
          request['type'] ?? 'borrow', // Default to borrow for compatibility
      'item_id': request['item_id'],
      'borrower_name': request['borrower_name'],
      'school_id': request['school_id'],
      'return_date': request['return_date'],
      'borrow_date': request['borrow_date'],
      'condition': request['condition'], // Nullable for borrows
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
}
