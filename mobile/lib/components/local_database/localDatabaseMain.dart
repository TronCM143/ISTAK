  import 'package:sqflite/sqflite.dart';
  import 'package:path/path.dart' as p;
  import 'dart:convert';

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
        version: 7,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE borrow_requests (
              id TEXT PRIMARY KEY,
              type TEXT,
              school_id TEXT,
              name TEXT,
              status TEXT,
              return_date TEXT,
              borrow_date TEXT,
              item_ids TEXT,
              photo_path TEXT,
              is_synced INTEGER,
              request_status TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              school_id TEXT,
              name TEXT,
              status TEXT,
              borrow_date TEXT,
              return_date TEXT,
              item_ids TEXT,
              photo_path TEXT,
              transaction_status TEXT,
              is_synced INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE items (
              id TEXT PRIMARY KEY,
              item_name TEXT,
              condition TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 7) {
            await db.execute('DROP TABLE IF EXISTS borrow_requests');
            await db.execute('DROP TABLE IF EXISTS transactions');
            await db.execute('DROP TABLE IF EXISTS items');
            await db.execute('''
              CREATE TABLE borrow_requests (
                id TEXT PRIMARY KEY,
                type TEXT,
                school_id TEXT,
                name TEXT,
                status TEXT,
                return_date TEXT,
                borrow_date TEXT,
                item_ids TEXT,
                photo_path TEXT,
                is_synced INTEGER,
                request_status TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                school_id TEXT,
                name TEXT,
                status TEXT,
                borrow_date TEXT,
                return_date TEXT,
                item_ids TEXT,
                photo_path TEXT,
                transaction_status TEXT,
                is_synced INTEGER
              )
            ''');
            await db.execute('''
              CREATE TABLE items (
                id TEXT PRIMARY KEY,
                item_name TEXT,
                condition TEXT
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
        'school_id': request['school_id'],
        'name': request['name'],
        'status': request['status'] ?? 'active',
        'return_date': request['return_date'],
        'borrow_date': request['borrow_date'],
        'item_ids': jsonEncode(request['item_ids']),
        'photo_path': request['photo_path'],
        'is_synced': request['is_synced'] == '1' ? 1 : 0,
        'request_status': request['request_status'] ?? 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    Future<List<Map<String, dynamic>>> getPendingRequests({
      String type = 'borrow',
    }) async {
      final db = await database;
      final results = await db.query(
        'borrow_requests',
        where: 'is_synced = ? AND request_status = ? AND type = ?',
        whereArgs: [0, 'pending', type],
      );
      return results
          .map(
            (r) => {
              ...r,
              'item_ids': jsonDecode(r['item_ids'] as String),
              'is_synced': r['is_synced'] == 1 ? '1' : '0',
            },
          )
          .toList();
    }

    Future<void> deleteBorrowRequest(String requestId) async {
      final db = await database;
      await db.delete('borrow_requests', where: 'id = ?', whereArgs: [requestId]);
    }

    Future<void> saveItemDetails(Map<String, dynamic> item) async {
      final db = await database;
      await db.insert('items', {
        'id': item['id'].toString(),
        'item_name': item['item_name'],
        'condition': item['condition'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    Future<Map<String, dynamic>?> getItemDetails(String itemId) async {
      final db = await database;
      final results = await db.query(
        'items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (results.isEmpty) return null;
      return results.first;
    }

    Future<Map<String, dynamic>?> getTransactionByItemId(String itemId) async {
      final db = await database;
      final results = await db.query(
        'transactions',
        where:
            'item_ids LIKE ? AND transaction_status = ? AND return_date IS NULL',
        whereArgs: ['%$itemId%', 'borrowed'],
      );
      if (results.isEmpty) return null;
      final transaction = results.first;
      return {
        ...transaction,
        'item_ids': jsonDecode(transaction['item_ids'] as String),
        'is_synced': transaction['is_synced'] == 1 ? '1' : '0',
      };
    }

    Future<void> saveTransaction(Map<String, dynamic> transaction) async {
      final db = await database;
      await db.insert('transactions', {
        'id': transaction['id'],
        'school_id': transaction['school_id'],
        'name': transaction['name'],
        'status': transaction['status'],
        'borrow_date': transaction['borrow_date'],
        'return_date': transaction['return_date'],
        'item_ids': jsonEncode(transaction['item_ids']),
        'photo_path': transaction['photo_path'],
        'transaction_status': transaction['transaction_status'],
        'is_synced': transaction['is_synced'] == '1' ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    Future<List<Map<String, dynamic>>> getAllTransactions() async {
      final db = await database;
      final results = await db.query('transactions');
      return results
          .map(
            (t) => {
              ...t,
              'item_ids': jsonDecode(t['item_ids'] as String),
              'is_synced': t['is_synced'] == 1 ? '1' : '0',
            },
          )
          .toList();
    }
  }
