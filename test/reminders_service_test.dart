import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:app_bank/services/reminders_service.dart';
import 'package:app_bank/services/db_service.dart';

void main() {
  late Database database;
  late RemindersService remindersService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create in-memory database for testing
    database = await openDatabase(
      p.join('', 'test_reminders.db'),
      onCreate: (db, version) async {
        // Create necessary tables
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            amount REAL,
            threshold REAL,
            enabled INTEGER DEFAULT 1,
            frequency TEXT,
            scheduledTime TEXT,
            createdAt TEXT NOT NULL,
            lastNotifiedAt TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            name TEXT NOT NULL
          );
        ''');
      },
      version: 1,
    );

    remindersService = RemindersService.instance;
  });

  tearDown(() async {
    await database.close();
  });

  group('RemindersService Tests', () {
    test('Create reminder successfully', () async {
      final reminder = await remindersService.createReminder(
        userId: 'user1',
        type: 'daily_expense',
        title: 'Daily Check',
        description: 'Check your expenses',
        frequency: 'daily',
        enabled: true,
      );

      expect(reminder.id, isNotEmpty);
      expect(reminder.userId, equals('user1'));
      expect(reminder.type, equals('daily_expense'));
      expect(reminder.enabled, isTrue);
    });

    test('Get user reminders', () async {
      const userId = 'user1';

      // Create multiple reminders
      await remindersService.createReminder(
        userId: userId,
        type: 'daily_expense',
        title: 'Reminder 1',
        description: 'Test reminder 1',
      );

      await remindersService.createReminder(
        userId: userId,
        type: 'budget_limit',
        title: 'Reminder 2',
        description: 'Test reminder 2',
      );

      final reminders = await remindersService.getUserReminders(userId);

      expect(reminders.length, equals(2));
      expect(reminders.every((r) => r.userId == userId), isTrue);
    });

    test('Get enabled reminders only', () async {
      const userId = 'user1';

      final enabled = await remindersService.createReminder(
        userId: userId,
        type: 'daily_expense',
        title: 'Enabled',
        description: 'This is enabled',
        enabled: true,
      );

      final disabled = await remindersService.createReminder(
        userId: userId,
        type: 'budget_limit',
        title: 'Disabled',
        description: 'This is disabled',
        enabled: false,
      );

      final enabledReminders = await remindersService.getEnabledReminders(userId);

      expect(enabledReminders.length, equals(1));
      expect(enabledReminders.first.id, equals(enabled.id));
    });

    test('Get reminders by type', () async {
      const userId = 'user1';

      await remindersService.createReminder(
        userId: userId,
        type: 'daily_expense',
        title: 'Daily 1',
        description: 'Daily reminder',
      );

      await remindersService.createReminder(
        userId: userId,
        type: 'daily_expense',
        title: 'Daily 2',
        description: 'Another daily reminder',
      );

      await remindersService.createReminder(
        userId: userId,
        type: 'budget_limit',
        title: 'Budget',
        description: 'Budget reminder',
      );

      final dailyReminders = await remindersService.getRemindersByType(
        userId,
        'daily_expense',
      );

      expect(dailyReminders.length, equals(2));
      expect(dailyReminders.every((r) => r.type == 'daily_expense'), isTrue);
    });

    test('Toggle reminder', () async {
      final reminder = await remindersService.createReminder(
        userId: 'user1',
        type: 'daily_expense',
        title: 'Test',
        description: 'Test',
        enabled: true,
      );

      await remindersService.toggleReminder(reminder.id, false);

      final reminders = await remindersService.getEnabledReminders('user1');
      expect(reminders.isEmpty, isTrue);
    });

    test('Update reminder', () async {
      final oldReminder = await remindersService.createReminder(
        userId: 'user1',
        type: 'daily_expense',
        title: 'Old Title',
        description: 'Old Description',
      );

      final updatedReminder = ReminderModel(
        id: oldReminder.id,
        userId: 'user1',
        type: 'budget_limit',
        title: 'New Title',
        description: 'New Description',
        enabled: true,
        createdAt: oldReminder.createdAt,
      );

      await remindersService.updateReminder(updatedReminder);

      final reminders = await remindersService.getUserReminders('user1');
      final updated = reminders.first;

      expect(updated.title, equals('New Title'));
      expect(updated.type, equals('budget_limit'));
    });

    test('Delete reminder', () async {
      final reminder = await remindersService.createReminder(
        userId: 'user1',
        type: 'daily_expense',
        title: 'To Delete',
        description: 'Will be deleted',
      );

      await remindersService.deleteReminder(reminder.id);

      final reminders = await remindersService.getUserReminders('user1');
      expect(reminders.isEmpty, isTrue);
    });

    test('Create budget reminder', () async {
      final reminder = await remindersService.createBudgetReminder(
        userId: 'user1',
        categoryName: 'Food',
        monthlyLimit: 500,
      );

      expect(reminder.type, equals('budget_limit'));
      expect(reminder.title, contains('Food'));
      expect(reminder.threshold, equals(500));
    });

    test('Create balance reminder', () async {
      final reminder = await remindersService.createBalanceReminder(
        userId: 'user1',
        accountName: 'Checking',
        warningThreshold: 1000,
      );

      expect(reminder.type, equals('balance_warning'));
      expect(reminder.title, contains('Checking'));
      expect(reminder.threshold, equals(1000));
    });
  });
}
