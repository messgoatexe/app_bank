import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:app_bank/services/offline_manager.dart';
import 'package:app_bank/services/db_service.dart';

void main() {
  late Database database;
  late OfflineManager offlineManager;

  setUpAll(() async {
    sqlfiteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create in-memory database for testing
    database = await openDatabase(
      p.join('', 'test_offline_manager.db'),
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
          CREATE TABLE IF NOT EXISTS conflict_resolutions (
            recordId TEXT PRIMARY KEY,
            entityType TEXT NOT NULL,
            resolution TEXT NOT NULL,
            resolvedAt TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_history (
            id TEXT PRIMARY KEY,
            syncedAt TEXT NOT NULL,
            successCount INTEGER,
            failureCount INTEGER,
            duration INTEGER
          );
        ''');
      },
      version: 1,
    );

    offlineManager = OfflineManager.instance;
  });

  tearDown(() async {
    await database.close();
  });

  group('OfflineManager Tests', () {
    test('Initialize offline manager', () async {
      await offlineManager.initialize();
      expect(offlineManager.isOnline, isNotNull);
    });

    test('Record change for offline transaction', () async {
      await offlineManager.initialize();

      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans1',
        action: 'create',
        data: {
          'amount': 100.0,
          'category': 'Food',
          'description': 'Lunch',
        },
      );

      expect(offlineManager.pendingChanges, greaterThan(0));
    });

    test('Get pending changes', () async {
      await offlineManager.initialize();

      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans1',
        action: 'create',
        data: {'amount': 100.0},
      );

      await offlineManager.recordChange(
        entityType: 'account',
        entityId: 'acc1',
        action: 'update',
        data: {'balance': 5000.0},
      );

      final changes = await offlineManager.getPendingChanges();
      expect(changes.length, equals(2));
    });

    test('Get changes by type', () async {
      await offlineManager.initialize();

      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans1',
        action: 'create',
        data: {'amount': 100.0},
      );

      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans2',
        action: 'create',
        data: {'amount': 50.0},
      );

      await offlineManager.recordChange(
        entityType: 'account',
        entityId: 'acc1',
        action: 'update',
        data: {'balance': 5000.0},
      );

      final transactionChanges = await offlineManager.getChangesByType('transaction');
      expect(transactionChanges.length, equals(2));
    });

    test('Mark changes as synced', () async {
      await offlineManager.initialize();

      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans1',
        action: 'create',
        data: {'amount': 100.0},
      );

      var changes = await offlineManager.getPendingChanges();
      expect(changes.length, equals(1));

      final changeId = changes.first['id'];
      await offlineManager.markAsSynced([changeId]);

      changes = await offlineManager.getPendingChanges();
      expect(changes.isEmpty, isTrue);
    });

    test('Detect conflicts', () async {
      await offlineManager.initialize();

      final localChanges = [
        {
          'id': 'change1',
          'entityId': 'trans1',
          'entityType': 'transaction',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'action': 'update',
        },
      ];

      final remoteChanges = [
        {
          'id': 'change2',
          'entityId': 'trans1',
          'entityType': 'transaction',
          'timestamp': DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch,
          'action': 'update',
        },
      ];

      final conflicts = await offlineManager.detectConflicts(
        localChanges,
        remoteChanges,
      );

      expect(conflicts.length, equals(1));
      expect(conflicts.first.resolution, equals('keep_local'));
    });

    test('Resolve conflicts', () async {
      await offlineManager.initialize();

      final conflict = ConflictResolution(
        recordId: 'change1',
        entityType: 'transaction',
        resolution: 'keep_local',
        resolvedAt: DateTime.now(),
      );

      await offlineManager.resolveConflicts([conflict]);

      final history = await offlineManager.getConflictHistory();
      expect(history.length, equals(1));
    });

    test('Get conflict history', () async {
      await offlineManager.initialize();

      final conflict1 = ConflictResolution(
        recordId: 'change1',
        entityType: 'transaction',
        resolution: 'keep_local',
        resolvedAt: DateTime.now(),
      );

      final conflict2 = ConflictResolution(
        recordId: 'change2',
        entityType: 'account',
        resolution: 'take_remote',
        resolvedAt: DateTime.now(),
      );

      await offlineManager.resolveConflicts([conflict1, conflict2]);

      final history = await offlineManager.getConflictHistory();
      expect(history.length, equals(2));
    });

    test('Get offline statistics', () async {
      await offlineManager.initialize();

      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans1',
        action: 'create',
        data: {'amount': 100.0},
      );

      await offlineManager.recordChange(
        entityType: 'account',
        entityId: 'acc1',
        action: 'update',
        data: {'balance': 5000.0},
      );

      final stats = await offlineManager.getOfflineStats();

      expect(stats['totalPending'], equals(2));
      expect(stats['changesByType'], isNotNull);
      expect(stats['changesByAction'], isNotNull);
    });

    test('Clear old history', () async {
      await offlineManager.initialize();

      // Record some changes
      await offlineManager.recordChange(
        entityType: 'transaction',
        entityId: 'trans1',
        action: 'create',
        data: {'amount': 100.0},
      );

      // Mark as synced to make it eligible for cleanup
      var changes = await offlineManager.getPendingChanges();
      await offlineManager.markAsSynced([changes.first['id']]);

      // Clear old history
      await offlineManager.clearOldHistory(daysToKeep: 0);

      changes = await offlineManager.getPendingChanges();
      // Should be empty after cleanup
      expect(changes.isEmpty, isTrue);
    });
  });
}
