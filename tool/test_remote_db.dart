import 'dart:async';
import 'dart:io';

import 'package:mysql1/mysql1.dart';

/// Simple script to test remote MySQL connectivity using the same settings
/// you put in your .env. It does NOT require flutter_dotenv: it reads .env
/// itself (if present) or falls back to environment variables.

Map<String, String> _loadEnvFile(File f) {
  final map = <String, String>{};
  if (!f.existsSync()) return map;
  final lines = f.readAsLinesSync();
  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    var val = line.substring(idx + 1).trim();
    // remove optional surrounding quotes
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.substring(1, val.length - 1);
    }
    map[key] = val;
  }
  return map;
}

Future<int> main(List<String> args) async {
  final cwd = Directory.current.path;
  final envFile = File('${cwd}${Platform.pathSeparator}.env');
  final env = _loadEnvFile(envFile);

  String host = env['DB_HOST'] ?? Platform.environment['DB_HOST'] ?? '10.0.2.2';
  final portStr = env['DB_PORT'] ?? Platform.environment['DB_PORT'] ?? '3306';
  final user = env['DB_USER'] ?? Platform.environment['DB_USER'] ?? 'root';
  final pass = env['DB_PASS'] ?? Platform.environment['DB_PASS'] ?? '';
  final db = env['DB_NAME'] ?? Platform.environment['DB_NAME'] ?? '';

  final port = int.tryParse(portStr) ?? 3306;

  print('Testing MySQL connection with: host=$host port=$port user=$user db=$db');

  final settings = ConnectionSettings(
    host: host,
    port: port,
    user: user,
    password: pass,
    db: db.isEmpty ? null : db,
  );

  MySqlConnection? conn;
  try {
    // attempt connect with timeout
    conn = await MySqlConnection.connect(settings).timeout(const Duration(seconds: 8));
    print('Connected to MySQL server. Running quick test query...');

    // run a simple query to check access to the database and the users table
    Results results;
    if (db.isNotEmpty) {
      results = await conn.query('SELECT DATABASE() as dbname');
      print('Current database: ' + (results.first['dbname']?.toString() ?? '<none>'));
    }

    // try to read a row from users table (if exists)
    try {
      results = await conn.query('SELECT id, email FROM users LIMIT 1');
      if (results.isEmpty) {
        print('Connected OK but `users` table is empty or does not exist.');
      } else {
        final row = results.first;
        print('Users table accessible. Example row: id=${row['id']}, email=${row['email']}');
      }
    } catch (e) {
      print('Could not query `users` table: $e');
    }

    await conn.close();
    print('Done. Connection closed.');
    return 0;
  } on TimeoutException catch (e) {
    stderr.writeln('Connection timed out: $e');
    return 2;
  } catch (e) {
    stderr.writeln('Connection error: $e');
    try {
      await conn?.close();
    } catch (_) {}
    return 1;
  }
}
