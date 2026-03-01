import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._private();
  static final NotificationService instance = NotificationService._private();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize timezone
    tzdata.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request permissions for iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse notificationResponse) {
    print(
        'Notification clicked: ${notificationResponse.payload}');
  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_notifications',
      'App Bank Notifications',
      channelDescription: 'Notifications de l\'application App Bank',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Schedule a notification at a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_notifications',
      'App Bank Notifications',
      channelDescription: 'Notifications de l\'application App Bank',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule a repeating notification (daily)
  Future<void> scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstScheduledDateTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_reminders',
      'App Bank Reminders',
      channelDescription: 'Rappels de l\'application App Bank',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(firstScheduledDateTime, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Show expense reminder notification
  Future<void> notifyExpenseAlert({
    required String categoryName,
    required double amount,
    required double limit,
  }) async {
    final percentage = (amount / limit * 100).toStringAsFixed(0);
    await showNotification(
      id: 1001,
      title: 'Alerte Budget: $categoryName',
      body: 'Vous avez dépensé $percentage% de votre budget ($amount€ / $limit€)',
      payload: 'expense_alert_$categoryName',
    );
  }

  /// Show daily reminder notification
  Future<void> notifyDailyReminder({
    required double totalSpent,
    required DateTime date,
  }) async {
    await showNotification(
      id: 1002,
      title: 'Rappel quotidien',
      body: 'Vous avez dépensé $totalSpent€ aujourd\'hui',
      payload: 'daily_reminder',
    );
  }

  /// Show budget warning notification
  Future<void> notifyBudgetWarning({
    required String accountName,
    required double currentBalance,
    required double warningThreshold,
  }) async {
    await showNotification(
      id: 1003,
      title: 'Avertissement Solde: $accountName',
      body:
          'Votre solde ($currentBalance€) est inférieur au seuil d\'alerte ($warningThreshold€)',
      payload: 'budget_warning_$accountName',
    );
  }

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Show notification with category icon
  Future<void> showCategoryNotification({
    required int id,
    required String categoryName,
    required double currentAmount,
    required double limit,
    required String emoji,
  }) async {
    final percentage = (currentAmount / limit * 100).toStringAsFixed(1);
    final isCritical = currentAmount > (limit * 0.9);
    
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alertes de dépassement de budget',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    final title = isCritical 
        ? '$emoji ALERTE: $categoryName' 
        : '$emoji Budget: $categoryName';
    final body = '$percentage% dépensé ($currentAmount€ / $limit€)';

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: 'budget_alert_$categoryName',
    );
  }

  /// Show shared expense notification
  Future<void> showSharedExpenseNotification({
    required int id,
    required String userName,
    required String description,
    required double amount,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_shared_expenses',
      'Shared Expenses',
      channelDescription: 'Notifications de dépenses partagées',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      '👥 Dépense partagée',
      '$userName a ajouté: $description ($amount€)',
      notificationDetails,
      payload: 'shared_expense_$userName',
    );
  }

  /// Show offline mode notification
  Future<void> showOfflineModeNotification({
    required int id,
    required bool isOffline,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_sync_status',
      'Sync Status',
      channelDescription: 'Statut de synchronisation',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    if (isOffline) {
      await _notificationsPlugin.show(
        id,
        '📵 Mode hors ligne',
        'Les modifications seront synchronisées quand la connexion sera rétablie',
        notificationDetails,
        payload: 'offline_mode',
      );
    } else {
      await _notificationsPlugin.show(
        id,
        '✅ Mode en ligne',
        'Synchronisation en cours...',
        notificationDetails,
        payload: 'online_mode',
      );
    }
  }

  /// Show sync completion notification
  Future<void> showSyncCompleteNotification({
    required int id,
    required int successCount,
    required int failureCount,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_bank_sync_complete',
      'Sync Complete',
      channelDescription: 'Notification de fin de synchronisation',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(),
    );

    final status = failureCount == 0 
        ? '✅ Synchronisation réussie'
        : '⚠️ Synchronisation partielle';
    final body = '$successCount ajouté, $failureCount échoué';

    await _notificationsPlugin.show(
      id,
      status,
      body,
      notificationDetails,
      payload: 'sync_complete',
    );
  }
}
