import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/category_model.dart';
import 'db_service.dart';
import 'remote_db_service.dart';

class SyncRecord {
  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String data;
  final bool synced;
  final DateTime createdAt;
  final DateTime? syncedAt;

  SyncRecord({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.data,
    required this.synced,
    required this.createdAt,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'action': action,
    'data': data,
    'synced': synced ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'syncedAt': syncedAt?.toIso8601String(),
  };

  factory SyncRecord.fromMap(Map<String, dynamic> map) => SyncRecord(
    id: map['id'],
    entityType: map['entityType'],
    entityId: map['entityId'],
    action: map['action'],
    data: map['data'],
    synced: map['synced'] == 1,
    createdAt: DateTime.parse(map['createdAt']),
    syncedAt:
        map['syncedAt'] != null ? DateTime.parse(map['syncedAt']) : null,
  );
}

class OfflineSyncService extends ChangeNotifier {
  OfflineSyncService._private();
  static final OfflineSyncService instance = OfflineSyncService._private();

  final _uuid = const Uuid();
  late Connectivity _connectivity;
  bool _isOnline = true;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    _connectivity = Connectivity();
    
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      notifyListeners();
      
      if (_isOnline) {
        print('[OfflineSyncService] Back online - starting sync');
        syncAll();
      } else {
        print('[OfflineSyncService] Offline mode');
      }
    });
  }

  /// Create sync record for offline operations
  Future<void> recordTransaction({
    required TransactionModel transaction,
    required String action,
  }) async {
    final db = DBService.instance.db;
    
    // Create sync tables if needed
    await _ensureSyncTablesExist();
    
    final syncRecord = SyncRecord(
      id: _uuid.v4(),
      entityType: 'transaction',
      entityId: transaction.id,
      action: action,
      data: transaction.toJson(),
      synced: false,
      createdAt: DateTime.now(),
    );
    
    await db.insert('sync_queue', syncRecord.toMap());
    notifyListeners();
  }

  /// Record account changes
  Future<void> recordAccount({
    required AccountModel account,
    required String action,
  }) async {
    final db = DBService.instance.db;
    await _ensureSyncTablesExist();
    
    final syncRecord = SyncRecord(
      id: _uuid.v4(),
      entityType: 'account',
      entityId: account.id,
      action: action,
      data: account.toJson(),
      synced: false,
      createdAt: DateTime.now(),
    );
    
    await db.insert('sync_queue', syncRecord.toMap());
    notifyListeners();
  }

  /// Record category changes
  Future<void> recordCategory({
    required CategoryModel category,
    required String action,
  }) async {
    final db = DBService.instance.db;
    await _ensureSyncTablesExist();
    
    final syncRecord = SyncRecord(
      id: _uuid.v4(),
      entityType: 'category',
      entityId: category.id,
      action: action,
      data: category.toJson(),
      synced: false,
      createdAt: DateTime.now(),
    );
    
    await db.insert('sync_queue', syncRecord.toMap());
    notifyListeners();
  }

  /// Sync all pending changes with remote database
  Future<bool> syncAll({bool force = false}) async {
    if (_isSyncing) return false;
    if (!_isOnline && !force) return false;

    _isSyncing = true;
    notifyListeners();

    try {
      final db = DBService.instance.db;
      await _ensureSyncTablesExist();
      
      final pendingRecords = await db.query(
        'sync_queue',
        where: 'synced = 0',
        orderBy: 'createdAt ASC',
      );

      if (pendingRecords.isEmpty) {
        print('[OfflineSyncService] No pending changes to sync');
        _isSyncing = false;
        notifyListeners();
        return true;
      }

      int successCount = 0;
      int failureCount = 0;

      for (final record in pendingRecords) {
        try {
          final syncRecord = SyncRecord.fromMap(record);
          await _syncRecord(syncRecord);
          successCount++;
        } catch (e) {
          print('[OfflineSyncService] Sync error: $e');
          failureCount++;
        }
      }

      print(
          '[OfflineSyncService] Sync completed: $successCount succeeded, $failureCount failed');
      
      _isSyncing = false;
      notifyListeners();
      
      return failureCount == 0;
    } catch (e) {
      print('[OfflineSyncService] Sync failed: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Sync a single record
  Future<void> _syncRecord(SyncRecord syncRecord) async {
    // This would sync with your remote database (MySQL via RemoteDBService)
    // For now, just mark as synced
    final db = DBService.instance.db;
    
    await db.update(
      'sync_queue',
      {
        'synced': 1,
        'syncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [syncRecord.id],
    );
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final db = DBService.instance.db;
    await _ensureSyncTablesExist();
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE synced = 0',
    );
    
    return (result.first['count'] as int?) ?? 0;
  }

  /// Clear completed sync records
  Future<void> clearSyncHistory() async {
    final db = DBService.instance.db;
    await _ensureSyncTablesExist();
    
    await db.delete('sync_queue', where: 'synced = 1');
  }

  /// Ensure sync tables exist
  Future<void> _ensureSyncTablesExist() async {
    final db = DBService.instance.db;
    
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          action TEXT NOT NULL,
          data TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          syncedAt TEXT
        );
      ''');
    } catch (e) {
      print('[OfflineSyncService] Error creating sync_queue table: $e');
    }
  }

  /// Get sync status
  Map<String, dynamic> getSyncStatus() => {
    'isOnline': _isOnline,
    'isSyncing': _isSyncing,
  };
}

extension on TransactionModel {
  String toJson() {
    return '''{
      "id": "$id",
      "userId": "$userId",
      "accountId": "$accountId",
      "amount": $amount,
      "type": "$type",
      "category": "$category",
      "description": "$description",
      "date": "${date.toIso8601String()}"
    }''';
  }
}

extension on AccountModel {
  String toJson() {
    return '''{
      "id": "$id",
      "userId": "$userId",
      "name": "$name",
      "balance": $balance,
      "currency": "$currency",
      "createdAt": "${createdAt.toIso8601String()}"
    }''';
  }
}

extension on CategoryModel {
  String toJson() {
    return '''{
      "id": "$id",
      "userId": "$userId",
      "name": "$name",
      "type": "$type",
      "color": "$color",
      "icon": "$icon",
      "createdAt": "${createdAt.toIso8601String()}"
    }''';
  }
}
