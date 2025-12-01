import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import 'db_service.dart';
import 'remote_db_service.dart';
import 'mock_db_service.dart';

class AuthService {
  AuthService._private();
  static final AuthService instance = AuthService._private();

  final _uuid = const Uuid();

  String _hash(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<UserModel?> signUp({required String email, required String password, String? displayName}) async {
  print('[AuthService] signUp: email=$email, displayName=$displayName');
  // Accès sécurisé à dotenv (compatible web)
  String? useMockStr, useRemoteStr;
  try {
    useMockStr = dotenv.env['USE_MOCK_DB'];
    useRemoteStr = dotenv.env['USE_REMOTE_DB'];
  } catch (e) {
    // Sur web, dotenv n'est pas initialisé - FORCER Mock DB
    print('[AuthService] Error reading dotenv: $e - forcing Mock DB on web');
    useMockStr = 'true';
    useRemoteStr = 'false';
  }
  final useMock = useMockStr == 'true';
  final useRemote = useRemoteStr == 'true';
  print('[AuthService] useMock=$useMock, useRemote=$useRemote');
    if (useMock) {
      print('[AuthService] Using MockDbService for signup');
      // create user in a local mock JSON DB (fast, file-based)
      final created = await MockDbService.instance.createUser(email: email, password: password, displayName: displayName);
      print('[AuthService] MockDbService signup result: ${created != null ? 'Success' : 'Failed'}');
      return created;
    }
    
    final id = _uuid.v4();
    if (useRemote) {
      print('[AuthService] Using RemoteDbService for signup (MySQL)');
      // create user on remote MySQL (bcrypt hashing handled there)
      try {
        final created = await RemoteDbService.instance.createUser(id: id, email: email, password: password, displayName: displayName);
        print('[AuthService] RemoteDbService signup result: ${created != null ? 'Success' : 'Failed'}');
        return created;
      } catch (e) {
        print('[AuthService] ❌ RemoteDbService signup error: $e');
        rethrow;
      }
    }

    print('[AuthService] Using local SQLite for signup');
    final db = DBService.instance.db;
    final hashed = _hash(password);
    final user = UserModel(id: id, email: email, hashedPassword: hashed, displayName: displayName);
    try {
      await db.insert('users', user.toMap());
      print('[AuthService] SQLite signup success');
      return user;
    } catch (e) {
      print('[AuthService] ❌ SQLite signup error: $e');
      // email déjà existant ou autre erreur
      return null;
    }
  }

  Future<UserModel?> signIn({required String email, required String password}) async {
    print('[AuthService] signIn: email=$email');
    // Accès sécurisé à dotenv (compatible web)
    String? useMockStr, useRemoteStr;
    try {
      useMockStr = dotenv.env['USE_MOCK_DB'];
      useRemoteStr = dotenv.env['USE_REMOTE_DB'];
    } catch (e) {
      // Sur web, dotenv n'est pas initialisé - forcer la mock DB
      print('[AuthService] Error reading dotenv: $e - forcing Mock DB');
      useMockStr = 'true';
      useRemoteStr = 'false';
    }
    final useMock = useMockStr == 'true';
    final useRemote = useRemoteStr == 'true';
    print('[AuthService] useMock=$useMock, useRemote=$useRemote');
    if (useMock) {
      print('[AuthService] Using MockDbService for signin');
      // verify against local mock DB
      final user = await MockDbService.instance.verifyLogin(email, password);
      print('[AuthService] MockDbService signin result: ${user != null ? 'Success' : 'Failed'}');
      return user;
    }
    if (useRemote) {
      print('[AuthService] Using RemoteDbService for signin (MySQL)');
      // verify via remote DB (bcrypt) with timeout and error handling to avoid blocking UI
      try {
        final user = await RemoteDbService.instance.verifyLogin(email, password).timeout(const Duration(seconds: 8));
        print('[AuthService] RemoteDbService signin result: ${user != null ? 'Success' : 'Failed'}');
        return user;
      } catch (e) {
        // connection error or timeout
        print('[AuthService] ❌ RemoteDbService signin error: $e');
        return null;
      }
    }

    print('[AuthService] Using local SQLite for signin');
    final db = DBService.instance.db;
    final hashed = _hash(password);
    final res = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (res.isEmpty) {
      print('[AuthService] User not found for email: $email');
      return null;
    }
    final user = UserModel.fromMap(res.first);
    if (user.hashedPassword == hashed) {
      print('[AuthService] SQLite signin success');
      return user;
    }
    print('[AuthService] ❌ Password mismatch');
    return null;
  }

  Future<UserModel?> getUserById(String id) async {
    // Accès sécurisé à dotenv (compatible web)
    String? useMockStr, useRemoteStr;
    try {
      useMockStr = dotenv.env['USE_MOCK_DB'];
      useRemoteStr = dotenv.env['USE_REMOTE_DB'];
    } catch (e) {
      // Sur web, dotenv n'est pas initialisé - forcer la mock DB
      useMockStr = 'true';
      useRemoteStr = 'false';
    }
    final useMock = useMockStr == 'true';
    final useRemote = useRemoteStr == 'true';
    if (useMock) {
      return await MockDbService.instance.getUserById(id);
    }
    if (useRemote) {
      return await RemoteDbService.instance.getUserById(id);
    }

    final db = DBService.instance.db;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  Future<bool> updateProfile({required String id, String? displayName}) async {
    // Accès sécurisé à dotenv (compatible web)
    String? useMockStr, useRemoteStr;
    try {
      useMockStr = dotenv.env['USE_MOCK_DB'];
      useRemoteStr = dotenv.env['USE_REMOTE_DB'];
    } catch (e) {
      // Sur web, dotenv n'est pas initialisé - forcer la mock DB
      useMockStr = 'true';
      useRemoteStr = 'false';
    }
    final useMock = useMockStr == 'true';
    final useRemote = useRemoteStr == 'true';
    if (useMock) {
      // naive implementation: read user, update displayName and write back
      // MockDbService doesn't expose update method; implement via get/create
      final user = await MockDbService.instance.getUserById(id);
      if (user == null) return false;
      // create a new entry by modifying file directly
      // Read & rewrite logic inside MockDbService is private; for simplicity, fallback to false
      return false;
    }
    if (useRemote) {
      // remote update not implemented in RemoteDbService; fall back to false
      return false;
    }

    final db = DBService.instance.db;
    final count = await db.update('users', {'displayName': displayName}, where: 'id = ?', whereArgs: [id]);
    return count == 1;
  }
}
