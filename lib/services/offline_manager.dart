import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'db_service.dart';
import 'notification_service.dart';

class ConflictResolution {
  final String recordId;
  final String entityType;
  final String resolution; // 'keep_local', 'take_remote', 'merge'
  final DateTime resolvedAt;

  ConflictResolution({
    required this.recordId,
    required this.entityType,
    required this.resolution,
    required this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
    'recordId': recordId,
    'entityType': entityType,
    'resolution': resolution,
    'resolvedAt': resolvedAt.toIso8601String(),
  };

  factory ConflictResolution.fromMap(Map<String, dynamic> map) =>
      ConflictResolution(
        recordId: map['recordId'],
        entityType: map['entityType'],
        resolution: map['resolution'],
        resolvedAt: DateTime.parse(map['resolvedAt']),
      );
}

class OfflineManager extends ChangeNotifier {
  OfflineManager._private();
  static final OfflineManager instance = OfflineManager._private();

  late Connectivity _connectivity;
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingChanges = 0;
  int _conflictCount = 0;
  DateTime? _lastSyncTime;
  final _uuid = const Uuid();

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingChanges => _pendingChanges;
  int get conflictCount => _conflictCount;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> initialize() async {
    await _ensureTablesExist();
    _connectivity = Connectivity();
    
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateOnlineStatus(result != ConnectivityResult.none);
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      _updateOnlineStatus(result != ConnectivityResult.none);
    });

    await _updatePendingChangesCount();
  }

  void _updateOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      print('[OfflineManager] Status changed to: ${online ? 'ONLINE' : 'OFFLINE'}');
      
      // Show notification
      NotificationService.instance.showOfflineModeNotification(
        id: 9001,
        isOffline: !online,
      );
      
      // Auto-sync when coming online
      if (online && _pendingChanges > 0) {
        print('[OfflineManager] Going online - starting sync');
        syncAll();
      }
      
      notifyListeners();
    }
  }

  /// Record any entity change for offline syncing
  Future<void> recordChange({
    required String entityType,
    required String entityId,
    required String action, // 'create', 'update', 'delete'
    required Map<String, dynamic> data,
  }) async {
    final db = DBService.instance.db;
    
    await db.insert(
      'offline_changes',
      {
        'id': _uuid.v4(),
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'data': _encodeData(data),
        'synced': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _updatePendingChangesCount();
    notifyListeners();
  }

  /// Get pending changes
  Future<List<Map<String, dynamic>>> getPendingChanges() async {
    final db = DBService.instance.db;
    await _ensureTablesExist();
    
    return await db.query(
      'offline_changes',
      where: 'synced = 0',
      orderBy: 'timestamp ASC',
    );
  }

  /// Get changes by entity type
  Future<List<Map<String, dynamic>>> getChangesByType(String entityType) async {
    final db = DBService.instance.db;
    await _ensureTablesExist();
    
    return await db.query(
      'offline_changes',
      where: 'entityType = ? AND synced = 0',
      whereArgs: [entityType],
      orderBy: 'timestamp ASC',
    );
  }

  /// Mark changes as synced
  Future<void> markAsSynced(List<String> changeIds) async {
    final db = DBService.instance.db;
    
    for (final id in changeIds) {
      await db.update(
        'offline_changes',
        {
          'synced': 1,
          'syncedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await _updatePendingChangesCount();
    notifyListeners();
  }

  /// Detect conflicts between local and remote data
  Future<List<ConflictResolution>> detectConflicts(
    List<Map<String, dynamic>> localChanges,
    List<Map<String, dynamic>> remoteChanges,
  ) async {
    final conflicts = <ConflictResolution>[];
    
    for (final local in localChanges) {
      final entityId = local['entityId'];
      final entityType = local['entityType'];
      
      // Find matching remote change
      final remoteChange = remoteChanges.firstWhere(
        (r) => r['entityId'] == entityId && r['entityType'] == entityType,
        orElse: () => {},
      );

      if (remoteChange.isNotEmpty) {
        // Conflict detected - both sides modified
        // Use timestamp-based resolution: newer wins
        final localTimestamp = int.parse(local['timestamp'].toString());
        final remoteTimestamp = int.parse(remoteChange['timestamp'].toString());
        
        final resolution = localTimestamp > remoteTimestamp
            ? 'keep_local'
            : 'take_remote';
        
        conflicts.add(ConflictResolution(
          recordId: local['id'],
          entityType: entityType,
          resolution: resolution,
          resolvedAt: DateTime.now(),
        ));
      }
    }

    _conflictCount = conflicts.length;
    notifyListeners();
    
    return conflicts;
  }

  /// Resolve conflicts
  Future<void> resolveConflicts(List<ConflictResolution> resolutions) async {
    final db = DBService.instance.db;
    
    for (final resolution in resolutions) {
      await db.insert(
        'conflict_resolutions',
        resolution.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    _conflictCount = 0;
    notifyListeners();
  }

  /// Get conflict history
  Future<List<ConflictResolution>> getConflictHistory() async {
    final db = DBService.instance.db;
    await _ensureTablesExist();
    
    final result = await db.query(
      'conflict_resolutions',
      orderBy: 'resolvedAt DESC',
      limit: 100,
    );

    return result.map((row) => ConflictResolution.fromMap(row)).toList();
  }

  /// Clear old history
  Future<void> clearOldHistory({int daysToKeep = 30}) async {
    final db = DBService.instance.db;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    // Delete synced changes
    await db.delete(
      'offline_changes',
      where: 'synced = 1 AND createdAt < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    // Delete old resolutions
    await db.delete(
      'conflict_resolutions',
      where: 'resolvedAt < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Sync all pending changes
  Future<bool> syncAll() async {
    if (!_isOnline || _isSyncing) return false;

    _isSyncing = true;
    notifyListeners();

    try {
      final changes = await getPendingChanges();
      
      if (changes.isEmpty) {
        print('[OfflineManager] No pending changes to sync');
        _isSyncing = false;
        _lastSyncTime = DateTime.now();
        notifyListeners();
        return true;
      }

      print('[OfflineManager] Syncing ${changes.length} changes');
      
      // Process changes
      int successCount = 0;
      int failureCount = 0;
      final changeIds = <String>[];

      for (final change in changes) {
        try {
          // Here you would call the remote sync service
          // For now, just mark as synced
          changeIds.add(change['id']);
          successCount++;
        } catch (e) {
          print('[OfflineManager] Sync error for ${change['id']}: $e');
          failureCount++;
        }
      }

      await markAsSynced(changeIds);

      // Show completion notification
      if (successCount > 0 || failureCount > 0) {
        await NotificationService.instance.showSyncCompleteNotification(
          id: 9002,
          successCount: successCount,
          failureCount: failureCount,
        );
      }

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();
      
      return failureCount == 0;
    } catch (e) {
      print('[OfflineManager] Sync failed: $e');
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Get offline statistics
  Future<Map<String, dynamic>> getOfflineStats() async {
    final db = DBService.instance.db;
    
    final changes = await getPendingChanges();
    final conflicts = await getConflictHistory();
    
    final byType = <String, int>{};
    final byAction = <String, int>{};

    for (final change in changes) {
      byType[change['entityType']] = (byType[change['entityType']] ?? 0) + 1;
      byAction[change['action']] = (byAction[change['action']] ?? 0) + 1;
    }

    return {
      'totalPending': changes.length,
      'totalConflicts': conflicts.length,
      'changesByType': byType,
      'changesByAction': byAction,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
    };
  }

  /// Update pending changes count
  Future<void> _updatePendingChangesCount() async {
    final db = DBService.instance.db;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_changes WHERE synced = 0',
    );
    
    _pendingChanges = (result.first['count'] as int?) ?? 0;
  }

  /// Ensure all required tables exist
  Future<void> _ensureTablesExist() async {
    final db = DBService.instance.db;

    try {
      // Offline changes tracking
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offline_changes (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          action TEXT NOT NULL,
          data TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          createdAt TEXT NOT NULL,
          syncedAt TEXT,
          timestamp INTEGER NOT NULL
        );
      ''');

      // Conflict resolutions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS conflict_resolutions (
          recordId TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          resolution TEXT NOT NULL,
          resolvedAt TEXT NOT NULL
        );
      ''');

      // Sync history
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_history (
          id TEXT PRIMARY KEY,
          syncedAt TEXT NOT NULL,
          successCount INTEGER,
          failureCount INTEGER,
          duration INTEGER
        );
      ''');
    } catch (e) {
      print('[OfflineManager] Error creating tables: $e');
    }
  }

  String _encodeData(Map<String, dynamic> data) {
    // Simple JSON encoding - in production use json.encode()
    return data.toString();
  }
}
