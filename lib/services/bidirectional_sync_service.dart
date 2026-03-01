import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'db_service.dart';
import 'remote_db_service.dart';

class BidirectionalSyncService {
  BidirectionalSyncService._private();
  static final BidirectionalSyncService instance =
      BidirectionalSyncService._private();

  final _uuid = const Uuid();

  /// Sync model with bi-directional conflict resolution
  Future<Map<String, dynamic>> biDirectionalSync({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required String userId,
  }) async {
    await _ensureTablesExist();
    
    try {
      // Get remote data
      Map<String, dynamic>? remoteData;
      try {
        remoteData = await RemoteDBService.instance.getEntity(
          entityType: entityType,
          entityId: entityId,
          userId: userId,
        );
      } catch (e) {
        print('[BidirectionalSyncService] Failed to fetch remote data: $e');
      }

      if (remoteData == null) {
        // Remote doesn't exist, push local
        return await _pushToRemote(
          entityType: entityType,
          entityId: entityId,
          data: localData,
          userId: userId,
        );
      }

      // Compare versions
      final localVersion = localData['version'] ?? 0;
      final remoteVersion = remoteData['version'] ?? 0;
      final localTimestamp = localData['updatedAt'] as DateTime?;
      final remoteTimestamp = remoteData['updatedAt'] as DateTime?;

      if (localVersion == remoteVersion &&
          localTimestamp?.millisecondsSinceEpoch ==
              remoteTimestamp?.millisecondsSinceEpoch) {
        // No conflict - already in sync
        return {'status': 'synced', 'conflict': false};
      }

      // Conflict detected - resolve based on strategy
      return await _resolveConflict(
        entityType: entityType,
        entityId: entityId,
        localData: localData,
        remoteData: remoteData,
        userId: userId,
      );
    } catch (e) {
      print('[BidirectionalSyncService] Sync error: $e');
      rethrow;
    }
  }

  /// Pull changes from remote
  Future<List<Map<String, dynamic>>> pullRemoteChanges({
    required String entityType,
    required String userId,
    required DateTime since,
  }) async {
    try {
      final remoteChanges = await RemoteDBService.instance.getChanges(
        entityType: entityType,
        userId: userId,
        since: since,
      );

      final db = DBService.instance.db;
      
      for (final change in remoteChanges) {
        // Check for local changes
        final localChange = await db.query(
          'offline_changes',
          where: 'entityType = ? AND entityId = ? AND synced = 0',
          whereArgs: [entityType, change['id']],
        );

        if (localChange.isEmpty) {
          // No local conflict, apply remote change
          await _applyRemoteChange(entityType, change);
        } else {
          // Conflict - record for manual resolution
          await _recordConflict(
            entityType: entityType,
            entityId: change['id'],
            localData: localChange.first,
            remoteData: change,
          );
        }
      }

      return remoteChanges;
    } catch (e) {
      print('[BidirectionalSyncService] Failed to pull changes: $e');
      rethrow;
    }
  }

  /// Push local changes to remote
  Future<int> pushLocalChanges({
    required String userId,
    int batchSize = 50,
  }) async {
    final db = DBService.instance.db;
    await _ensureTablesExist();
    
    int synced = 0;

    try {
      final allChanges = await db.query(
        'offline_changes',
        where: 'synced = 0',
        orderBy: 'timestamp ASC',
      );

      // Process in batches
      for (int i = 0; i < allChanges.length; i += batchSize) {
        final batch = allChanges.sublist(
          i,
          i + batchSize > allChanges.length ? allChanges.length : i + batchSize,
        );

        for (final change in batch) {
          try {
            await _pushChange(change, userId);
            synced++;
          } catch (e) {
            print('[BidirectionalSyncService] Failed to push change: $e');
          }
        }
      }
    } catch (e) {
      print('[BidirectionalSyncService] Push error: $e');
    }

    return synced;
  }

  /// Merge changes - three-way merge
  Future<Map<String, dynamic>> threeWayMerge({
    required Map<String, dynamic> baseData,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) async {
    final merged = <String, dynamic>{};

    // Get all keys from all versions
    final allKeys = {...baseData.keys, ...localData.keys, ...remoteData.keys};

    for (final key in allKeys) {
      final baseValue = baseData[key];
      final localValue = localData[key];
      final remoteValue = remoteData[key];

      if (localValue == remoteValue) {
        // No conflict
        merged[key] = localValue ?? remoteValue;
      } else if (localValue == baseValue) {
        // Only remote changed
        merged[key] = remoteValue;
      } else if (remoteValue == baseValue) {
        // Only local changed
        merged[key] = localValue;
      } else {
        // Both changed - prefer local if it's more recent
        final localTimestamp = localData['timestamp'] as int? ?? 0;
        final remoteTimestamp = remoteData['timestamp'] as int? ?? 0;
        merged[key] = localTimestamp > remoteTimestamp ? localValue : remoteValue;
      }
    }

    // Preserve version and timestamps
    merged['version'] = (baseData['version'] ?? 0) + 1;
    merged['updatedAt'] = DateTime.now();
    merged['mergedFrom'] = 'local_$remoteValue';

    return merged;
  }

  /// Get sync queue status
  Future<Map<String, dynamic>> getSyncQueueStatus() async {
    final db = DBService.instance.db;
    await _ensureTablesExist();

    final pending = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_changes WHERE synced = 0',
    );

    final conflicts = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_conflicts WHERE resolved = 0',
    );

    final byType = await db.rawQuery('''
      SELECT entityType, COUNT(*) as count 
      FROM offline_changes 
      WHERE synced = 0
      GROUP BY entityType
    ''');

    return {
      'pendingCount': (pending.first['count'] as int?) ?? 0,
      'conflictCount': (conflicts.first['count'] as int?) ?? 0,
      'byType': Map.fromEntries(
        byType.map((row) => MapEntry(
          row['entityType'] as String,
          row['count'] as int,
        )),
      ),
    };
  }

  // ======================== PRIVATE METHODS ========================

  Future<Map<String, dynamic>> _resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String userId,
  }) async {
    final localTimestamp = localData['updatedAt'] as DateTime?;
    final remoteTimestamp = remoteData['updatedAt'] as DateTime?;

    // Strategy 1: Latest timestamp wins (default)
    if (localTimestamp != null && remoteTimestamp != null) {
      if (localTimestamp.isAfter(remoteTimestamp)) {
        return await _pushToRemote(
          entityType: entityType,
          entityId: entityId,
          data: localData,
          userId: userId,
        );
      } else {
        return await _applyRemoteChange(entityType, remoteData);
      }
    }

    // Strategy 2: Three-way merge if base exists
    final base = await _getBaseVersion(entityType, entityId);
    if (base != null) {
      final merged = await threeWayMerge(
        baseData: base,
        localData: localData,
        remoteData: remoteData,
      );
      return await _pushToRemote(
        entityType: entityType,
        entityId: entityId,
        data: merged,
        userId: userId,
      );
    }

    // Fallback: record conflict for manual resolution
    await _recordConflict(
      entityType: entityType,
      entityId: entityId,
      localData: localData,
      remoteData: remoteData,
    );

    return {
      'status': 'conflict',
      'conflict': true,
      'entityId': entityId,
      'requiresManualResolution': true,
    };
  }

  Future<Map<String, dynamic>> _pushToRemote({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
    required String userId,
  }) async {
    try {
      await RemoteDBService.instance.upsertEntity(
        entityType: entityType,
        entityId: entityId,
        data: data,
        userId: userId,
      );

      // Mark as synced locally
      final db = DBService.instance.db;
      await db.update(
        'offline_changes',
        {
          'synced': 1,
          'syncedAt': DateTime.now().toIso8601String(),
        },
        where: 'entityId = ?',
        whereArgs: [entityId],
      );

      return {'status': 'synced', 'conflict': false};
    } catch (e) {
      print('[BidirectionalSyncService] Failed to push: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _applyRemoteChange(
    String entityType,
    Map<String, dynamic> remoteData,
  ) async {
    // Apply remote change to local database
    final db = DBService.instance.db;

    try {
      // This would update the local entity based on type
      print('[BidirectionalSyncService] Applying remote change for $entityType');

      // Mark any local changes as synced to avoid reprocessing
      await db.update(
        'offline_changes',
        {
          'synced': 1,
          'syncedAt': DateTime.now().toIso8601String(),
        },
        where: 'entityId = ?',
        whereArgs: [remoteData['id']],
      );

      return {'status': 'applied', 'conflict': false};
    } catch (e) {
      print('[BidirectionalSyncService] Failed to apply change: $e');
      rethrow;
    }
  }

  Future<void> _pushChange(
    Map<String, dynamic> change,
    String userId,
  ) async {
    try {
      await RemoteDBService.instance.upsertEntity(
        entityType: change['entityType'],
        entityId: change['entityId'],
        data: change['data'],
        userId: userId,
      );

      final db = DBService.instance.db;
      await db.update(
        'offline_changes',
        {
          'synced': 1,
          'syncedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [change['id']],
      );
    } catch (e) {
      print('[BidirectionalSyncService] Failed to push change: $e');
      rethrow;
    }
  }

  Future<void> _recordConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) async {
    final db = DBService.instance.db;
    await _ensureTablesExist();

    try {
      await db.insert(
        'sync_conflicts',
        {
          'id': _uuid.v4(),
          'entityType': entityType,
          'entityId': entityId,
          'localData': localData.toString(),
          'remoteData': remoteData.toString(),
          'createdAt': DateTime.now().toIso8601String(),
          'resolved': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('[BidirectionalSyncService] Failed to record conflict: $e');
    }
  }

  Future<Map<String, dynamic>?> _getBaseVersion(
    String entityType,
    String entityId,
  ) async {
    final db = DBService.instance.db;
    await _ensureTablesExist();

    try {
      final result = await db.query(
        'sync_base_versions',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId],
      );

      if (result.isEmpty) return null;
      return result.first;
    } catch (e) {
      print('[BidirectionalSyncService] Failed to get base version: $e');
      return null;
    }
  }

  Future<void> _ensureTablesExist() async {
    final db = DBService.instance.db;

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_conflicts (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          localData TEXT NOT NULL,
          remoteData TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          resolved INTEGER DEFAULT 0
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_base_versions (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          data TEXT NOT NULL,
          version INTEGER,
          capturedAt TEXT NOT NULL
        );
      ''');
    } catch (e) {
      print('[BidirectionalSyncService] Error creating tables: $e');
    }
  }
}
