import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import 'db_service.dart';
import 'notification_service.dart';

class ReminderModel {
  final String id;
  final String userId;
  final String type; // 'daily_expense', 'budget_limit', 'balance_warning'
  final String title;
  final String description;
  final double? amount;
  final double? threshold;
  final bool enabled;
  final String? frequency; // 'daily', 'weekly', 'monthly', 'once'
  final DateTime? scheduledTime;
  final DateTime createdAt;
  final DateTime? lastNotifiedAt;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.amount,
    this.threshold,
    required this.enabled,
    this.frequency,
    this.scheduledTime,
    required this.createdAt,
    this.lastNotifiedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'type': type,
    'title': title,
    'description': description,
    'amount': amount,
    'threshold': threshold,
    'enabled': enabled ? 1 : 0,
    'frequency': frequency,
    'scheduledTime': scheduledTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'lastNotifiedAt': lastNotifiedAt?.toIso8601String(),
  };

  factory ReminderModel.fromMap(Map<String, dynamic> map) => ReminderModel(
    id: map['id'],
    userId: map['userId'],
    type: map['type'],
    title: map['title'],
    description: map['description'],
    amount: map['amount']?.toDouble(),
    threshold: map['threshold']?.toDouble(),
    enabled: map['enabled'] == 1,
    frequency: map['frequency'],
    scheduledTime: map['scheduledTime'] != null 
        ? DateTime.parse(map['scheduledTime']) 
        : null,
    createdAt: DateTime.parse(map['createdAt']),
    lastNotifiedAt: map['lastNotifiedAt'] != null
        ? DateTime.parse(map['lastNotifiedAt'])
        : null,
  );
}

class RemindersService {
  RemindersService._private();
  static final RemindersService instance = RemindersService._private();

  final _uuid = const Uuid();

  Future<void> _ensureTablesExist() async {
    final db = DBService.instance.db;
    try {
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
          lastNotifiedAt TEXT,
          FOREIGN KEY(userId) REFERENCES users(id)
        );
      ''');
    } catch (e) {
      print('Error creating reminders table: $e');
    }
  }

  /// Create a new reminder
  Future<ReminderModel> createReminder({
    required String userId,
    required String type,
    required String title,
    required String description,
    double? amount,
    double? threshold,
    bool enabled = true,
    String? frequency,
    DateTime? scheduledTime,
  }) async {
    await _ensureTablesExist();
    
    final reminder = ReminderModel(
      id: _uuid.v4(),
      userId: userId,
      type: type,
      title: title,
      description: description,
      amount: amount,
      threshold: threshold,
      enabled: enabled,
      frequency: frequency,
      scheduledTime: scheduledTime,
      createdAt: DateTime.now(),
    );

    final db = DBService.instance.db;
    await db.insert('reminders', reminder.toMap());
    
    return reminder;
  }

  /// Get all reminders for a user
  Future<List<ReminderModel>> getUserReminders(String userId) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    final result = await db.query(
      'reminders',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return result.map((row) => ReminderModel.fromMap(row)).toList();
  }

  /// Get enabled reminders only
  Future<List<ReminderModel>> getEnabledReminders(String userId) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    final result = await db.query(
      'reminders',
      where: 'userId = ? AND enabled = 1',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return result.map((row) => ReminderModel.fromMap(row)).toList();
  }

  /// Get reminders by type
  Future<List<ReminderModel>> getRemindersByType(
    String userId,
    String type,
  ) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    final result = await db.query(
      'reminders',
      where: 'userId = ? AND type = ?',
      whereArgs: [userId, type],
      orderBy: 'createdAt DESC',
    );

    return result.map((row) => ReminderModel.fromMap(row)).toList();
  }

  /// Update a reminder
  Future<void> updateReminder(ReminderModel reminder) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  /// Enable/disable reminder
  Future<void> toggleReminder(String reminderId, bool enabled) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    await db.update(
      'reminders',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  /// Update last notified time
  Future<void> updateLastNotified(String reminderId) async {
    await _ensureTablesExist();
    
    final db = DBService.instance.db;
    await db.update(
      'reminders',
      {'lastNotifiedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  /// Check and trigger reminders for a user
  Future<void> checkAndTriggerReminders(String userId) async {
    final reminders = await getEnabledReminders(userId);
    final now = DateTime.now();

    for (final reminder in reminders) {
      bool shouldNotify = false;

      // Check based on frequency
      if (reminder.lastNotifiedAt == null) {
        shouldNotify = true;
      } else if (reminder.frequency == 'daily') {
        final lastNotified = reminder.lastNotifiedAt!;
        shouldNotify = lastNotified.day != now.day ||
            lastNotified.month != now.month ||
            lastNotified.year != now.year;
      } else if (reminder.frequency == 'weekly') {
        final lastNotified = reminder.lastNotifiedAt!;
        shouldNotify = now.difference(lastNotified).inDays >= 7;
      } else if (reminder.frequency == 'monthly') {
        final lastNotified = reminder.lastNotifiedAt!;
        shouldNotify = now.difference(lastNotified).inDays >= 30;
      }

      // Check scheduled time
      if (reminder.scheduledTime != null) {
        final scheduled = reminder.scheduledTime!;
        final isTimeToNotify = now.hour == scheduled.hour &&
            now.minute == scheduled.minute;
        shouldNotify = shouldNotify && isTimeToNotify;
      }

      if (shouldNotify) {
        await _sendReminderNotification(reminder);
        await updateLastNotified(reminder.id);
      }
    }
  }

  /// Send reminder notification
  Future<void> _sendReminderNotification(ReminderModel reminder) async {
    try {
      switch (reminder.type) {
        case 'daily_expense':
          await NotificationService.instance.showNotification(
            id: reminder.id.hashCode,
            title: 'Rappel: ${reminder.title}',
            body: reminder.description,
            payload: 'reminder_${reminder.id}',
          );
          break;

        case 'budget_limit':
          await NotificationService.instance.showNotification(
            id: reminder.id.hashCode,
            title: '⚠️ ${reminder.title}',
            body: reminder.description,
            payload: 'reminder_${reminder.id}',
          );
          break;

        case 'balance_warning':
          await NotificationService.instance.showNotification(
            id: reminder.id.hashCode,
            title: '💰 ${reminder.title}',
            body: reminder.description,
            payload: 'reminder_${reminder.id}',
          );
          break;

        default:
          await NotificationService.instance.showNotification(
            id: reminder.id.hashCode,
            title: reminder.title,
            body: reminder.description,
            payload: 'reminder_${reminder.id}',
          );
      }
    } catch (e) {
      print('[RemindersService] Error sending notification: $e');
    }
  }

  /// Create budget limit reminder
  Future<ReminderModel> createBudgetReminder({
    required String userId,
    required String categoryName,
    required double monthlyLimit,
  }) async {
    return createReminder(
      userId: userId,
      type: 'budget_limit',
      title: 'Limite Budget: $categoryName',
      description: 'Budget mensuel: ${monthlyLimit.toStringAsFixed(2)}€',
      threshold: monthlyLimit,
      frequency: 'daily',
      enabled: true,
    );
  }

  /// Create balance warning reminder
  Future<ReminderModel> createBalanceReminder({
    required String userId,
    required String accountName,
    required double warningThreshold,
  }) async {
    return createReminder(
      userId: userId,
      type: 'balance_warning',
      title: 'Alerte Solde: $accountName',
      description: 'Alerte si solde < ${warningThreshold.toStringAsFixed(2)}€',
      threshold: warningThreshold,
      frequency: 'daily',
      enabled: true,
    );
  }

  /// Create daily expense reminder
  Future<ReminderModel> createDailyExpenseReminder({
    required String userId,
    required DateTime time,
  }) async {
    return createReminder(
      userId: userId,
      type: 'daily_expense',
      title: 'Rappel quotidien',
      description: 'N\'oubliez pas de vérifier vos dépenses du jour',
      frequency: 'daily',
      scheduledTime: time,
      enabled: true,
    );
  }
}
