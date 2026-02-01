import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';

class ExpenseReminder {
  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final double dailyLimit;
  final double weeklyLimit;
  final double monthlyLimit;
  final bool enableNotifications;
  final double alertThreshold; // 0.0 to 1.0 (0% to 100%)
  final DateTime createdAt;

  ExpenseReminder({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    this.dailyLimit = 0,
    this.weeklyLimit = 0,
    this.monthlyLimit = 0,
    this.enableNotifications = true,
    this.alertThreshold = 0.8,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'dailyLimit': dailyLimit,
    'weeklyLimit': weeklyLimit,
    'monthlyLimit': monthlyLimit,
    'enableNotifications': enableNotifications ? 1 : 0,
    'alertThreshold': alertThreshold,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ExpenseReminder.fromMap(Map<String, dynamic> map) => ExpenseReminder(
    id: map['id'],
    userId: map['userId'],
    categoryId: map['categoryId'],
    categoryName: map['categoryName'],
    dailyLimit: map['dailyLimit']?.toDouble() ?? 0.0,
    weeklyLimit: map['weeklyLimit']?.toDouble() ?? 0.0,
    monthlyLimit: map['monthlyLimit']?.toDouble() ?? 0.0,
    enableNotifications: map['enableNotifications'] == 1,
    alertThreshold: map['alertThreshold']?.toDouble() ?? 0.8,
    createdAt: DateTime.parse(map['createdAt']),
  );
}

class RemindersProvider extends ChangeNotifier {
  RemindersProvider._private();
  static final RemindersProvider instance = RemindersProvider._private();

  final _uuid = const Uuid();
  List<ExpenseReminder> _reminders = [];
  bool _initialized = false;

  List<ExpenseReminder> get reminders => _reminders;

  Future<void> initialize(String userId) async {
    if (_initialized) return;
    await _ensureTablesExist();
    await _loadReminders(userId);
    _initialized = true;
  }

  Future<void> _ensureTablesExist() async {
    final db = DBService.instance.db;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expense_reminders (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          categoryId TEXT NOT NULL,
          categoryName TEXT NOT NULL,
          dailyLimit REAL DEFAULT 0,
          weeklyLimit REAL DEFAULT 0,
          monthlyLimit REAL DEFAULT 0,
          enableNotifications INTEGER DEFAULT 1,
          alertThreshold REAL DEFAULT 0.8,
          createdAt TEXT NOT NULL,
          FOREIGN KEY(userId) REFERENCES users(id)
        );
      ''');
    } catch (e) {
      print('Error creating expense_reminders table: $e');
    }
  }

  Future<void> _loadReminders(String userId) async {
    final db = DBService.instance.db;
    final result = await db.query(
      'expense_reminders',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    _reminders = result.map((r) => ExpenseReminder.fromMap(r)).toList();
    notifyListeners();
  }

  /// Create a new expense reminder
  Future<ExpenseReminder> createReminder({
    required String userId,
    required String categoryId,
    required String categoryName,
    double dailyLimit = 0,
    double weeklyLimit = 0,
    double monthlyLimit = 0,
    bool enableNotifications = true,
    double alertThreshold = 0.8,
  }) async {
    final db = DBService.instance.db;
    final reminder = ExpenseReminder(
      id: _uuid.v4(),
      userId: userId,
      categoryId: categoryId,
      categoryName: categoryName,
      dailyLimit: dailyLimit,
      weeklyLimit: weeklyLimit,
      monthlyLimit: monthlyLimit,
      enableNotifications: enableNotifications,
      alertThreshold: alertThreshold,
      createdAt: DateTime.now(),
    );

    await db.insert('expense_reminders', reminder.toMap());
    _reminders.add(reminder);
    notifyListeners();
    return reminder;
  }

  /// Update a reminder
  Future<bool> updateReminder(ExpenseReminder reminder) async {
    final db = DBService.instance.db;
    final count = await db.update(
      'expense_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
    
    if (count > 0) {
      final index = _reminders.indexWhere((r) => r.id == reminder.id);
      if (index != -1) {
        _reminders[index] = reminder;
        notifyListeners();
      }
    }
    return count > 0;
  }

  /// Delete a reminder
  Future<bool> deleteReminder(String reminderId) async {
    final db = DBService.instance.db;
    final count = await db.delete(
      'expense_reminders',
      where: 'id = ?',
      whereArgs: [reminderId],
    );
    
    if (count > 0) {
      _reminders.removeWhere((r) => r.id == reminderId);
      notifyListeners();
    }
    return count > 0;
  }

  /// Check category spending against reminders
  Future<void> checkCategorySpending(
    String userId,
    String categoryId,
    String categoryName,
    double dailySpent,
    double weeklySpent,
    double monthlySpent,
  ) async {
    final reminder = _reminders.firstWhere(
      (r) => r.categoryId == categoryId,
      orElse: () => null as ExpenseReminder,
    );

    if (reminder == null || !reminder.enableNotifications) return;

    // Check daily limit
    if (reminder.dailyLimit > 0) {
      final percentage = dailySpent / reminder.dailyLimit;
      if (percentage >= reminder.alertThreshold) {
        await NotificationService.instance.notifyExpenseAlert(
          categoryName: categoryName,
          amount: dailySpent,
          limit: reminder.dailyLimit,
        );
      }
    }

    // Check weekly limit
    if (reminder.weeklyLimit > 0) {
      final percentage = weeklySpent / reminder.weeklyLimit;
      if (percentage >= reminder.alertThreshold) {
        await NotificationService.instance.notifyExpenseAlert(
          categoryName: '$categoryName (hebdomadaire)',
          amount: weeklySpent,
          limit: reminder.weeklyLimit,
        );
      }
    }

    // Check monthly limit
    if (reminder.monthlyLimit > 0) {
      final percentage = monthlySpent / reminder.monthlyLimit;
      if (percentage >= reminder.alertThreshold) {
        await NotificationService.instance.notifyExpenseAlert(
          categoryName: '$categoryName (mensuel)',
          amount: monthlySpent,
          limit: reminder.monthlyLimit,
        );
      }
    }
  }

  /// Schedule daily reminder for a category
  Future<void> scheduleDailyReminder(
    ExpenseReminder reminder,
    double currentSpending,
  ) async {
    final now = DateTime.now();
    final reminderTime = DateTime(now.year, now.month, now.day, 20, 0);
    
    if (reminderTime.isBefore(now)) {
      reminderTime.add(const Duration(days: 1));
    }

    await NotificationService.instance.scheduleRecurringNotification(
      id: reminderTime.day,
      title: 'Rappel: ${reminder.categoryName}',
      body:
          'Vous avez dépensé $currentSpending€ en ${reminder.categoryName} aujourd\'hui',
      firstScheduledDateTime: reminderTime,
      payload: 'daily_reminder_${reminder.categoryId}',
    );
  }
}
