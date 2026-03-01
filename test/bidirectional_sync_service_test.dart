import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:app_bank/services/bidirectional_sync_service.dart';
import 'package:app_bank/services/db_service.dart';

void main() {
  late Database database;
  late BidirectionalSyncService syncService;

  setUpAll(() async {
    sqlfiteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create in-memory database for testing
    database = await openDatabase(
      p.join('', 'test_bidirectional_sync.db'),
      onCreate: (db, version) async {
        // Create necessary tables
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
      },
      version: 1,
    );

    syncService = BidirectionalSyncService.instance;
  });

  tearDown(() async {
    await database.close();
  });

  group('BidirectionalSyncService Tests', () {
    test('Three-way merge without conflicts', () async {
      final baseData = {
        'id': 'test1',
        'amount': 100.0,
        'category': 'Food',
        'version': 1,
      };

      final localData = {
        'id': 'test1',
        'amount': 100.0,
        'category': 'Food',
        'version': 1,
        'description': 'Lunch',
      };

      final remoteData = {
        'id': 'test1',
        'amount': 150.0,
        'category': 'Food',
        'version': 1,
      };

      final merged = await syncService.threeWayMerge(
        baseData: baseData,
        localData: localData,
        remoteData: remoteData,
      );

      expect(merged['id'], equals('test1'));
      expect(merged['description'], equals('Lunch'));
      expect(merged['amount'], equals(150.0));
    });

    test('Three-way merge with conflicting changes', () async {
      final now = DateTime.now();
      final before = now.subtract(Duration(hours: 1));

      final baseData = {
        'id': 'test1',
        'amount': 100.0,
        'version': 1,
      };

      final localData = {
        'id': 'test1',
        'amount': 200.0,
        'version': 1,
        'timestamp': now.millisecondsSinceEpoch,
      };

      final remoteData = {
        'id': 'test1',
        'amount': 150.0,
        'version': 1,
        'timestamp': before.millisecondsSinceEpoch,
      };

      final merged = await syncService.threeWayMerge(
        baseData: baseData,
        localData: localData,
        remoteData: remoteData,
      );

      // Local should win as it's more recent
      expect(merged['amount'], equals(200.0));
    });

    test('Get sync queue status empty', () async {
      final status = await syncService.getSyncQueueStatus();

      expect(status['pendingCount'], equals(0));
      expect(status['conflictCount'], equals(0));
    });

    test('Get sync queue status with pending changes', () async {
      // Record a change directly in database
      await database.insert(
        'offline_changes',
        {
          'id': 'change1',
          'entityType': 'transaction',
          'entityId': 'trans1',
          'action': 'create',
          'data': '{"amount": 100}',
          'synced': 0,
          'createdAt': DateTime.now().toIso8601String(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      final status = await syncService.getSyncQueueStatus();
      expect(status['pendingCount'], equals(1));
    });

    test('Merge strategy - remote deleted, local modified', () async {
      final baseData = {
        'id': 'test1',
        'amount': 100.0,
        'deleted': false,
      };

      final localData = {
        'id': 'test1',
        'amount': 150.0,
        'deleted': false,
      };

      final remoteData = {
        'id': 'test1',
        'amount': 100.0,
        'deleted': true,
      };

      final merged = await syncService.threeWayMerge(
        baseData: baseData,
        localData: localData,
        remoteData: remoteData,
      );

      // This tests that the merge handles partial deletions
      expect(merged['id'], equals('test1'));
      expect(merged.containsKey('version'), isTrue);
    });

    test('Handle empty remote data gracefully', () async {
      final localData = {
        'id': 'test1',
        'amount': 100.0,
      };

      final remoteData = <String, dynamic>{};

      final merged = await syncService.threeWayMerge(
        baseData: {},
        localData: localData,
        remoteData: remoteData,
      );

      expect(merged['id'], equals('test1'));
      expect(merged['amount'], equals(100.0));
    });

    test('Preserve metadata in merge', () async {
      final now = DateTime.now();

      final baseData = {
        'id': 'test1',
        'amount': 100.0,
      };

      final localData = {
        'id': 'test1',
        'amount': 150.0,
        'timestamp': now.millisecondsSinceEpoch,
      };

      final remoteData = {
        'id': 'test1',
        'amount': 120.0,
        'timestamp': now.subtract(Duration(hours: 1)).millisecondsSinceEpoch,
      };

      final merged = await syncService.threeWayMerge(
        baseData: baseData,
        localData: localData,
        remoteData: remoteData,
      );

      // Metadata should be preserved
      expect(merged['version'], isNotNull);
      expect(merged['updatedAt'], isNotNull);
      expect(merged['mergedFrom'], isNotNull);
    });
  });
}
