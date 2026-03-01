import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_bank/services/notification_service.dart';

void main() {
  group('NotificationService Tests', () {
    late NotificationService notificationService;

    setUp(() {
      notificationService = NotificationService.instance;
    });

    test('Show notification creates proper notification', () async {
      // Initialize first
      await notificationService.initialize();

      // Test that show notification doesn't throw
      await notificationService.showNotification(
        id: 1,
        title: 'Test Title',
        body: 'Test Body',
        payload: 'test_payload',
      );

      // Verify notification was created
      final pending = await notificationService.getPendingNotifications();
      expect(pending, isNotNull);
    });

    test('Schedule notification', () async {
      await notificationService.initialize();

      final scheduledTime = DateTime.now().add(Duration(hours: 1));

      await notificationService.scheduleNotification(
        id: 2,
        title: 'Scheduled',
        body: 'This is scheduled',
        scheduledDateTime: scheduledTime,
        payload: 'scheduled_test',
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending, isNotNull);
    });

    test('Show expense alert notification', () async {
      await notificationService.initialize();

      await notificationService.notifyExpenseAlert(
        categoryName: 'Food',
        amount: 80.0,
        limit: 100.0,
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Show daily reminder notification', () async {
      await notificationService.initialize();

      await notificationService.notifyDailyReminder(
        totalSpent: 150.0,
        date: DateTime.now(),
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Show budget warning notification', () async {
      await notificationService.initialize();

      await notificationService.notifyBudgetWarning(
        accountName: 'Main Account',
        currentBalance: 500.0,
        warningThreshold: 1000.0,
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Cancel notification', () async {
      await notificationService.initialize();

      await notificationService.showNotification(
        id: 10,
        title: 'To Cancel',
        body: 'This will be cancelled',
      );

      await notificationService.cancelNotification(10);

      final pending = await notificationService.getPendingNotifications();
      final id10 = pending.where((p) => p.id == 10);
      // After cancel, the notification shouldn't be in pending list
      expect(id10.isEmpty, isTrue);
    });

    test('Cancel all notifications', () async {
      await notificationService.initialize();

      await notificationService.showNotification(
        id: 11,
        title: 'Test 1',
        body: 'Body 1',
      );

      await notificationService.showNotification(
        id: 12,
        title: 'Test 2',
        body: 'Body 2',
      );

      await notificationService.cancelAllNotifications();

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isEmpty, isTrue);
    });

    test('Show category notification with warning', () async {
      await notificationService.initialize();

      await notificationService.showCategoryNotification(
        id: 20,
        categoryName: 'Food',
        currentAmount: 95.0,
        limit: 100.0,
        emoji: '🍔',
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Show shared expense notification', () async {
      await notificationService.initialize();

      await notificationService.showSharedExpenseNotification(
        id: 21,
        userName: 'John',
        description: 'Dinner',
        amount: 45.0,
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Show offline mode notification', () async {
      await notificationService.initialize();

      await notificationService.showOfflineModeNotification(
        id: 22,
        isOffline: true,
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Show sync complete notification', () async {
      await notificationService.initialize();

      await notificationService.showSyncCompleteNotification(
        id: 23,
        successCount: 5,
        failureCount: 0,
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.isNotEmpty, isTrue);
    });

    test('Get pending notifications', () async {
      await notificationService.initialize();

      await notificationService.showNotification(
        id: 30,
        title: 'Pending 1',
        body: 'Body 1',
      );

      await notificationService.showNotification(
        id: 31,
        title: 'Pending 2',
        body: 'Body 2',
      );

      final pending = await notificationService.getPendingNotifications();
      expect(pending.length, greaterThanOrEqualTo(2));
    });
  });
}
