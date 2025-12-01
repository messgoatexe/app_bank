import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBService {
  DBService._private();
  static final DBService instance = DBService._private();
  Database? _db;

  Future<void> init() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'app_bancaire.db');
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              email TEXT UNIQUE,
              hashedPassword TEXT,
              displayName TEXT
            );
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              amount REAL,
              type TEXT,
              category TEXT,
              description TEXT,
              date TEXT,
              FOREIGN KEY(user_id) REFERENCES users(id)
            );
          ''');
        },
      );
    } catch (e) {
      print('DBService.init() error: $e');
      rethrow;
    }
  }

  Database get db {
    if (_db == null) throw Exception('Database not initialized');
    return _db!;
  }
}
