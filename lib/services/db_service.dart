import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
        version: 2,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createNewTablesV2(db);
          }
        },
      );
    } catch (e) {
      print('DBService.init() error: $e');
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    // Table des utilisateurs
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        hashedPassword TEXT,
        displayName TEXT
      );
    ''');

    // Table des comptes
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'EUR',
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id)
      );
    ''');

    // Table des catégories
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT,
        icon TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id),
        UNIQUE(user_id, name)
      );
    ''');

    // Table des transactions
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        account_id TEXT,
        amount REAL,
        type TEXT,
        category TEXT,
        description TEXT,
        date TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(account_id) REFERENCES accounts(id)
      );
    ''');

    // Table des budgets partagés
    await db.execute('''
      CREATE TABLE shared_budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        monthly_limit REAL NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // Table des membres de budgets partagés
    await db.execute('''
      CREATE TABLE budget_members (
        budget_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT NOT NULL,
        PRIMARY KEY (budget_id, user_id),
        FOREIGN KEY(budget_id) REFERENCES shared_budgets(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      );
    ''');

    // Créer les index
    await db.execute('CREATE INDEX idx_accounts_user ON accounts(user_id);');
    await db.execute('CREATE INDEX idx_categories_user ON categories(user_id);');
    await db.execute('CREATE INDEX idx_transactions_user ON transactions(user_id);');
    await db.execute('CREATE INDEX idx_transactions_account ON transactions(account_id);');
    await db.execute('CREATE INDEX idx_budget_members_user ON budget_members(user_id);');
  }

  Future<void> _createNewTablesV2(Database db) async {
    // Créer les nouvelles tables lors de la migration depuis v1
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'EUR',
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT,
        icon TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id),
        UNIQUE(user_id, name)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shared_budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        monthly_limit REAL NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_members (
        budget_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT NOT NULL,
        PRIMARY KEY (budget_id, user_id),
        FOREIGN KEY(budget_id) REFERENCES shared_budgets(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      );
    ''');

    // Ajouter la colonne account_id à transactions si elle n'existe pas
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN account_id TEXT;');
    } catch (e) {
      // La colonne existe déjà
    }

    // Créer les index
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts(user_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_budget_members_user ON budget_members(user_id);');
  }

  Database get db {
    if (kIsWeb) {
      throw Exception('Cannot access SQLite database on web platform. Web platform does not support local file access.');
    }
    if (_db == null) throw Exception('Database not initialized');
    return _db!;
  }
}
