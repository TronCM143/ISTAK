import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items (
            id TEXT PRIMARY KEY,
            item_name TEXT,
            condition TEXT,
            current_transaction TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            item_id TEXT,
            item_name TEXT,
            borrower_name TEXT,
            school_id TEXT,
            borrow_date TEXT,
            return_date TEXT,
            photo_path TEXT,
            image_url TEXT,
            status TEXT,
            is_synced INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE borrow_requests (
            id TEXT PRIMARY KEY,
            type TEXT,
            school_id TEXT,
            borrower_name TEXT,
            status TEXT,
            return_date TEXT,
            borrow_date TEXT,
            item_id TEXT,
            photo_path TEXT,
            image_url TEXT,
            condition TEXT,
            is_synced INTEGER,
            request_status TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN image_url TEXT',
          );
          await db.execute(
            'ALTER TABLE borrow_requests ADD COLUMN image_url TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE borrow_requests ADD COLUMN condition TEXT',
          );
        }
      },
    );
  }

  Future<Map<String, dynamic>?> getItemDetails(String itemId) async {
    final db = await database;
    final result = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> saveItemDetails(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      'items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTransactionByItemId(String itemId) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> saveTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    await db.insert('transactions', {
      ...transaction,
      'is_synced': transaction['is_synced'] is int
          ? transaction['is_synced']
          : int.parse(transaction['is_synced'].toString()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveBorrowRequest(Map<String, dynamic> request) async {
    final db = await database;
    await db.insert('borrow_requests', {
      ...request,
      'is_synced': request['is_synced'] is int
          ? request['is_synced']
          : int.parse(request['is_synced'].toString()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingRequests({String? type}) async {
    final db = await database;
    return await db.query(
      'borrow_requests',
      where:
          'is_synced = ? AND request_status = ?' +
          (type != null ? ' AND type = ?' : ''),
      whereArgs: type != null ? [0, 'pending', type] : [0, 'pending'],
    );
  }

  Future<void> updateRequestStatus(
    String id,
    String status,
    int isSynced,
  ) async {
    final db = await database;
    await db.update(
      'borrow_requests',
      {'request_status': status, 'is_synced': isSynced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBorrowRequest(String id) async {
    final db = await database;
    await db.delete('borrow_requests', where: 'id = ?', whereArgs: [id]);
  }
}
