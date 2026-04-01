import 'package:uuid/uuid.dart';

/// Modèle pour les transactions récurrentes
class RecurringTransaction {
  final String id;
  final String description;
  final double amount;
  final String category;
  final RecurrenceFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<DateTime> executedDates;

  RecurringTransaction({
    String? id,
    required this.description,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.executedDates = const [],
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'frequency': frequency.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'executedDates': executedDates.map((d) => d.toIso8601String()).join(','),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      frequency: RecurrenceFrequency.values.byName(map['frequency'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate'] as String) : null,
      isActive: (map['isActive'] as int) == 1,
      executedDates: (map['executedDates'] as String).isEmpty
          ? []
          : (map['executedDates'] as String).split(',').map((d) => DateTime.parse(d)).toList(),
    );
  }

  RecurringTransaction copyWith({
    String? id,
    String? description,
    double? amount,
    String? category,
    RecurrenceFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<DateTime>? executedDates,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      executedDates: executedDates ?? this.executedDates,
    );
  }
}

/// Fréquence de récurrence
enum RecurrenceFrequency {
  daily,
  weekly,
  biWeekly,
  monthly,
  quarterly,
  semiAnnually,
  annually,
}

/// Service pour gérer les transactions récurrentes
class RecurringTransactionsService {
  static final RecurringTransactionsService _instance =
      RecurringTransactionsService._internal();

  final List<RecurringTransaction> _recurringTransactions = [];

  factory RecurringTransactionsService() {
    return _instance;
  }

  RecurringTransactionsService._internal();

  /// Ajoute une transaction récurrente
  void addRecurringTransaction(RecurringTransaction recurring) {
    _recurringTransactions.add(recurring);
  }

  /// Met à jour une transaction récurrente
  void updateRecurringTransaction(RecurringTransaction recurring) {
    final index = _recurringTransactions.indexWhere((t) => t.id == recurring.id);
    if (index != -1) {
      _recurringTransactions[index] = recurring;
    }
  }

  /// Supprime une transaction récurrente
  void deleteRecurringTransaction(String id) {
    _recurringTransactions.removeWhere((t) => t.id == id);
  }

  /// Récupère une transaction récurrente
  RecurringTransaction? getRecurringTransaction(String id) {
    try {
      return _recurringTransactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Récupère toutes les transactions récurrentes actives
  List<RecurringTransaction> getActiveRecurringTransactions() {
    return _recurringTransactions.where((t) => t.isActive).toList();
  }

  /// Récupère toutes les transactions récurrentes
  List<RecurringTransaction> getAllRecurringTransactions() {
    return _recurringTransactions.toList();
  }

  /// Détermine si une transaction récurrente doit être exécutée aujourd'hui
  bool shouldExecuteToday(RecurringTransaction recurring) {
    final today = DateTime.now();
    final nextExecutionDate = getNextExecutionDate(recurring);

    if (nextExecutionDate == null) {
      return false;
    }

    return _isSameDay(nextExecutionDate, today);
  }

  /// Obtient la date suivante d'exécution
  DateTime? getNextExecutionDate(RecurringTransaction recurring) {
    if (!recurring.isActive) {
      return null;
    }

    if (recurring.endDate != null && recurring.endDate!.isBefore(DateTime.now())) {
      return null;
    }

    DateTime nextDate = recurring.startDate;

    // Si la date de démarrage est dans le passé, calculer la prochaine date
    if (nextDate.isBefore(DateTime.now())) {
      nextDate = _calculateNextExecutionDate(recurring.startDate, recurring.frequency);
    }

    // S'assurer que la date ne dépasse pas la date de fin
    if (recurring.endDate != null && nextDate.isAfter(recurring.endDate!)) {
      return null;
    }

    return nextDate;
  }

  /// Calcule la prochaine date d'exécution basée sur la fréquence
  DateTime _calculateNextExecutionDate(DateTime from, RecurrenceFrequency frequency) {
    final now = DateTime.now();
    var nextDate = from;

    // Boucler jusqu'à obtenir une date dans le futur
    while (nextDate.isBefore(now)) {
      switch (frequency) {
        case RecurrenceFrequency.daily:
          nextDate = nextDate.add(const Duration(days: 1));
          break;
        case RecurrenceFrequency.weekly:
          nextDate = nextDate.add(const Duration(days: 7));
          break;
        case RecurrenceFrequency.biWeekly:
          nextDate = nextDate.add(const Duration(days: 14));
          break;
        case RecurrenceFrequency.monthly:
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
          break;
        case RecurrenceFrequency.quarterly:
          nextDate = DateTime(nextDate.year, nextDate.month + 3, nextDate.day);
          break;
        case RecurrenceFrequency.semiAnnually:
          nextDate = DateTime(nextDate.year, nextDate.month + 6, nextDate.day);
          break;
        case RecurrenceFrequency.annually:
          nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
          break;
      }
    }

    return nextDate;
  }

  /// Marque une transaction récurrente comme exécutée
  void markAsExecuted(String recurringId, DateTime executionDate) {
    final recurring = getRecurringTransaction(recurringId);
    if (recurring != null) {
      final updatedDates = [...recurring.executedDates, executionDate];
      updateRecurringTransaction(recurring.copyWith(executedDates: updatedDates));
    }
  }

  /// Obtient le nombre de jours jusqu'à la prochaine exécution
  int? getDaysUntilExecution(RecurringTransaction recurring) {
    final nextDate = getNextExecutionDate(recurring);
    if (nextDate == null) {
      return null;
    }

    return nextDate.difference(DateTime.now()).inDays;
  }

  /// Obtient les transactions qui doivent être exécutées cette semaine
  List<RecurringTransaction> getThisWeekExecutions() {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));

    return getActiveRecurringTransactions().where((recurring) {
      final nextDate = getNextExecutionDate(recurring);
      if (nextDate == null) {
        return false;
      }
      return !nextDate.isBefore(now) && nextDate.isBefore(weekEnd);
    }).toList();
  }

  /// Obtient les transactions qui doivent être exécutées ce mois
  List<RecurringTransaction> getThisMonthExecutions() {
    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    return getActiveRecurringTransactions().where((recurring) {
      final nextDate = getNextExecutionDate(recurring);
      if (nextDate == null) {
        return false;
      }
      return !nextDate.isBefore(now) && nextDate.isBefore(monthEnd);
    }).toList();
  }

  /// Comparer deux dates en ignorant l'heure
  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
