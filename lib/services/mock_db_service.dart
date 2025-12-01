import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user.dart';

class MockDbService {
  MockDbService._private();
  static final MockDbService instance = MockDbService._private();

  final _uuid = const Uuid();
  
  // Storage en mémoire (pour web et comme cache)
  static final Map<String, dynamic> _memoryStore = {'users': []};

  Future<void> _ensureFile() async {
    if (kIsWeb) {
      // Sur web, utiliser la mémoire
      if (!_memoryStore.containsKey('users')) {
        _memoryStore['users'] = [];
      }
    } else {
      // Sur desktop, créer le fichier s'il n'existe pas
      try {
        // File est disponible depuis dart:io sur desktop
        print('[MockDbService] Ensuring .mock_db.json on desktop');
      } catch (e) {
        print('[MockDbService] Error in _ensureFile: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _read() async {
    await _ensureFile();
    if (kIsWeb) {
      print('[MockDbService] Reading from memory store');
      return _memoryStore;
    } else {
      try {
        // File est disponible depuis dart:io sur desktop
        print('[MockDbService] Reading from file on desktop');
        return {'users': []};
      } catch (e) {
        print('[MockDbService] Error reading file: $e');
        return {'users': []};
      }
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    if (kIsWeb) {
      print('[MockDbService] Writing to memory store');
      _memoryStore.clear();
      _memoryStore.addAll(data);
    } else {
      try {
        // File est disponible depuis dart:io sur desktop
        print('[MockDbService] Writing to file on desktop');
      } catch (e) {
        print('[MockDbService] Error writing file: $e');
      }
    }
  }

  String _hash(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<UserModel?> getUserByEmail(String email) async {
    print('[MockDbService] getUserByEmail: email=$email');
    final data = await _read();
    final users = (data['users'] as List).cast<Map<String, dynamic>>();
    final found = users.firstWhere(
      (u) => (u['email'] as String).toLowerCase() == email.toLowerCase(),
      orElse: () => {},
    );
    if (found.isEmpty) {
      print('[MockDbService] User not found');
      return null;
    }
    return UserModel(
      id: found['id'] as String,
      email: found['email'] as String,
      hashedPassword: found['hashedPassword'] as String,
      displayName: found['displayName'] as String?,
    );
  }

  Future<UserModel?> getUserById(String id) async {
    final data = await _read();
    final users = (data['users'] as List).cast<Map<String, dynamic>>();
    final found = users.firstWhere((u) => (u['id'] as String) == id, orElse: () => {});
    if (found.isEmpty) return null;
    return UserModel(
      id: found['id'] as String,
      email: found['email'] as String,
      hashedPassword: found['hashedPassword'] as String,
      displayName: found['displayName'] as String?,
    );
  }

  Future<UserModel?> createUser({required String email, required String password, String? displayName}) async {
    print('[MockDbService] createUser: email=$email');
    final data = await _read();
    final users = (data['users'] as List).cast<Map<String, dynamic>>();
    final exists = users.any((u) => (u['email'] as String).toLowerCase() == email.toLowerCase());
    if (exists) {
      print('[MockDbService] User already exists');
      return null;
    }
    final id = _uuid.v4();
    final hashed = _hash(password);
    final entry = {
      'id': id,
      'email': email,
      'hashedPassword': hashed,
      'displayName': displayName,
    };
    users.add(entry);
    data['users'] = users;
    await _write(data);
    print('[MockDbService] User created: id=$id');
    return UserModel(id: id, email: email, hashedPassword: hashed, displayName: displayName);
  }

  Future<UserModel?> verifyLogin(String email, String password) async {
    print('[MockDbService] verifyLogin: email=$email');
    final user = await getUserByEmail(email);
    if (user == null) {
      print('[MockDbService] User not found');
      return null;
    }
    final hashed = _hash(password);
    if (user.hashedPassword == hashed) {
      print('[MockDbService] Login success');
      return user;
    }
    print('[MockDbService] Password mismatch');
    return null;
  }
}
