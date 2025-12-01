import 'package:mysql1/mysql1.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bcrypt/bcrypt.dart';
import '../models/user.dart';

class RemoteDbService {
  RemoteDbService._private();
  static final RemoteDbService instance = RemoteDbService._private();

  MySqlConnection? _conn;

  Future<void> init() async {
    print('[RemoteDbService] Initializing...');
    try {
      await dotenv.load();
      print('[RemoteDbService] dotenv.load() completed');
    } catch (e) {
      print('[RemoteDbService] dotenv.load() error: $e');
    }
    
    // Accès sécurisé à dotenv (compatible web)
    String? dbHost, dbPort, dbUser, dbPass, dbName;
    try {
      dbHost = dotenv.env['DB_HOST'];
      dbPort = dotenv.env['DB_PORT'];
      dbUser = dotenv.env['DB_USER'];
      dbPass = dotenv.env['DB_PASS'];
      dbName = dotenv.env['DB_NAME'];
      print('[RemoteDbService] Dotenv values: host=$dbHost, port=$dbPort, user=$dbUser, db=$dbName');
    } catch (e) {
      print('[RemoteDbService] Error reading dotenv: $e');
    }
    
    final host = dbHost ?? '10.0.2.2';
    final port = int.tryParse(dbPort ?? '3306') ?? 3306;
    final user = dbUser ?? 'root';
    final pass = (dbPass == null || dbPass.isEmpty) ? null : dbPass;
    final db = dbName ?? '';

    print('[RemoteDbService] Connecting to MySQL: host=$host, port=$port, user=$user, db=$db, password=$pass');

    var settings = ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: pass,
      db: db,
      // default timeout is fine
    );

    try {
      // protect against long blocking connect by using timeout
      _conn = await MySqlConnection.connect(settings).timeout(const Duration(seconds: 6));
      print('[RemoteDbService] ✅ Connected successfully to MySQL');
    } catch (e) {
      // connection failed or timed out
      print('[RemoteDbService] ❌ Connection error: $e');
      _conn = null;
      rethrow;
    }
  }

  Future<void> close() async {
    await _conn?.close();
    _conn = null;
  }

  /// Get user row by email. Returns null if not found.
  Future<UserModel?> getUserByEmail(String email) async {
    if (_conn == null) await init();
    final results = await _conn!.query(
      'SELECT id, email, hashed_password, display_name FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    if (results.isEmpty) return null;
    final row = results.first;
    // Map DB columns to UserModel fields. Adjust column names if needed.
    final id = row['id']?.toString() ?? '';
    final em = row['email']?.toString() ?? '';
    final hash = row['hashed_password']?.toString() ?? '';
    final displayName = row['display_name']?.toString();

    return UserModel(id: id, email: em, hashedPassword: hash, displayName: displayName);
  }

  /// Get user by id
  Future<UserModel?> getUserById(String id) async {
    if (_conn == null) await init();
    final results = await _conn!.query(
      'SELECT id, email, hashed_password, display_name FROM users WHERE id = ? LIMIT 1',
      [id],
    );
    if (results.isEmpty) return null;
    final row = results.first;
    final em = row['email']?.toString() ?? '';
    final hash = row['hashed_password']?.toString() ?? '';
    final displayName = row['display_name']?.toString();
    return UserModel(id: id, email: em, hashedPassword: hash, displayName: displayName);
  }

  /// Create a new user in remote DB. Returns true on success.
  /// Create a new user in remote DB. Returns the created UserModel (with hashedPassword) or null on failure.
  Future<UserModel?> createUser({required String id, required String email, required String password, String? displayName}) async {
    if (_conn == null) await init();
    final hashed = BCrypt.hashpw(password, BCrypt.gensalt());
    try {
      await _conn!.query(
        'INSERT INTO users (id, email, hashed_password, display_name) VALUES (?, ?, ?, ?)',
        [id, email, hashed, displayName],
      );
      return UserModel(id: id, email: email, hashedPassword: hashed, displayName: displayName);
    } catch (e) {
      print('Remote createUser error: $e');
      return null;
    }
  }

  /// Verify a user's password (bcrypt) and return the UserModel if OK
  Future<UserModel?> verifyLogin(String email, String password) async {
    try {
      final user = await getUserByEmail(email);
      if (user == null) return null;
      final hash = user.hashedPassword;
      final ok = BCrypt.checkpw(password, hash);
      if (ok) return user;
      return null;
    } catch (e) {
      print('RemoteDbService.verifyLogin error: $e');
      return null;
    }
  }
}
