import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

/// Service pour l'analyse complète des données financières
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() {
    return _instance;
  }

  AnalyticsService._internal();

  /// Calcule les statistiques par catégorie pour une période
  Map<String, dynamic> getCategoryStats(
    List<Transaction> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filtered = _filterTransactionsByDate(transactions, startDate, endDate);
    final categories = <String, double>{};
    final counts = <String, int>{};

    for (var transaction in filtered) {
      if (transaction.amount > 0) {
        // Seulement les dépenses
        categories[transaction.category] =
            (categories[transaction.category] ?? 0) + transaction.amount;
        counts[transaction.category] = (counts[transaction.category] ?? 0) + 1;
      }
    }

    return {
      'categories': categories,
      'counts': counts,
      'total': categories.values.fold<double>(0, (a, b) => a + b),
      'average':
          categories.isEmpty ? 0 : (categories.values.reduce((a, b) => a + b) / categories.length),
    };
  }

  /// Calcule les statistiques quotidiennes
  Map<String, dynamic> getDailyStats(
    List<Transaction> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filtered = _filterTransactionsByDate(transactions, startDate, endDate);
    final dailyData = <String, double>{};
    final format = DateFormat('dd/MM/yyyy');

    for (var transaction in filtered) {
      final day = format.format(transaction.date);
      if (transaction.amount > 0) {
        dailyData[day] = (dailyData[day] ?? 0) + transaction.amount;
      }
    }

    return {
      'daily': dailyData,
      'average': dailyData.isEmpty ? 0 : (dailyData.values.reduce((a, b) => a + b) / dailyData.length),
    };
  }

  /// Calcule les statistiques par type (income/expense)
  Map<String, dynamic> getTypeStats(
    List<Transaction> transactions, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filtered = _filterTransactionsByDate(transactions, startDate, endDate);
    double income = 0;
    double expense = 0;
    int incomeCount = 0;
    int expenseCount = 0;

    for (var transaction in filtered) {
      if (transaction.amount > 0) {
        income += transaction.amount;
        incomeCount++;
      } else {
        expense += transaction.amount.abs();
        expenseCount++;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
      'incomeCount': incomeCount,
      'expenseCount': expenseCount,
      'incomePercentage': (income + expense) > 0 ? (income / (income + expense)) * 100 : 0,
      'expensePercentage': (income + expense) > 0 ? (expense / (income + expense)) * 100 : 0,
    };
  }

  /// Analyse les tendances mensuelles
  Map<String, dynamic> getMonthlyTrends(List<Transaction> transactions) {
    final monthlyData = <String, double>{};
    final monthlyExpense = <String, double>{};
    final format = DateFormat('MMM yyyy', 'en_US');

    for (var transaction in transactions) {
      final month = format.format(transaction.date);
      if (transaction.amount > 0) {
        monthlyData[month] = (monthlyData[month] ?? 0) + transaction.amount;
      } else {
        monthlyExpense[month] = (monthlyExpense[month] ?? 0) + transaction.amount.abs();
      }
    }

    return {
      'monthlyIncome': monthlyData,
      'monthlyExpense': monthlyExpense,
      'months': monthlyData.keys.toList(),
    };
  }

  /// Calcule les statistiques de budget par catégorie pour le mois en cours
  Map<String, dynamic> getBudgetAnalysis(
    List<Transaction> transactions, {
    Map<String, double>? budgetLimits,
  }) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final filtered = _filterTransactionsByDate(transactions, startOfMonth, endOfMonth);
    final categorySpending = <String, double>{};

    for (var transaction in filtered) {
      if (transaction.amount > 0) {
        categorySpending[transaction.category] =
            (categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    final budgetAnalysis = <String, dynamic>{};
    if (budgetLimits != null) {
      for (var category in budgetLimits.keys) {
        final spent = categorySpending[category] ?? 0;
        final limit = budgetLimits[category] ?? 0;
        final percentage = limit > 0 ? (spent / limit) * 100 : 0;

        budgetAnalysis[category] = {
          'limit': limit,
          'spent': spent,
          'remaining': limit - spent,
          'percentage': percentage,
          'isExceeded': spent > limit,
        };
      }
    }

    return budgetAnalysis;
  }

  /// Obtient les catégories avec les dépenses les plus élevées
  List<Map<String, dynamic>> getTopCategories(
    List<Transaction> transactions, {
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final stats = getCategoryStats(transactions, startDate: startDate, endDate: endDate);
    final categories = stats['categories'] as Map<String, double>;

    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((entry) {
      return {
        'category': entry.key,
        'amount': entry.value,
        'percentage': (categories.values.reduce((a, b) => a + b)) > 0
            ? (entry.value / categories.values.reduce((a, b) => a + b)) * 100
            : 0,
      };
    }).toList();
  }

  /// Détecte les anomalies de dépenses
  List<Map<String, dynamic>> detectAnomalies(
    List<Transaction> transactions, {
    double threshold = 2.0, // écart-type
  }) {
    final stats = getDailyStats(transactions);
    final dailyData = stats['daily'] as Map<String, double>;

    if (dailyData.isEmpty) return [];

    final average = stats['average'] as double;
    final values = dailyData.values.toList();

    // Calculer l'écart-type
    final variance = values.fold<double>(0, (sum, value) => sum + (value - average) * (value - average)) / values.length;
    final stdDev = variance > 0 ? (variance.isNaN ? 0 : variance).toDouble().abs().sqrt() : 0;

    final anomalies = <Map<String, dynamic>>[];
    dailyData.forEach((day, amount) {
      if (stdDev > 0 && ((amount - average).abs() / stdDev) > threshold) {
        anomalies.add({
          'date': day,
          'amount': amount,
          'deviation': ((amount - average) / average * 100).toStringAsFixed(2),
        });
      }
    });

    return anomalies;
  }

  /// Calcule les prévisions pour le mois suivant basées sur les tendances
  Map<String, dynamic> forecastNextMonth(List<Transaction> transactions) {
    final monthlyStats = getMonthlyTrends(transactions);
    final monthlyExpense = monthlyStats['monthlyExpense'] as Map<String, double>;
    final monthlyIncome = monthlyStats['monthlyIncome'] as Map<String, double>;

    // Utiliser les 3 derniers mois pour la prévision
    final recentExpense = monthlyExpense.values.toList().take(3).toList();
    final recentIncome = monthlyIncome.values.toList().take(3).toList();

    final avgExpense = recentExpense.isEmpty ? 0 : (recentExpense.reduce((a, b) => a + b) / recentExpense.length);
    final avgIncome = recentIncome.isEmpty ? 0 : (recentIncome.reduce((a, b) => a + b) / recentIncome.length);

    return {
      'forecastedExpense': avgExpense,
      'forecastedIncome': avgIncome,
      'forecastedBalance': avgIncome - avgExpense,
      'trend': recentExpense.length > 1
          ? recentExpense.last > recentExpense.first
              ? 'increasing'
              : 'decreasing'
          : 'stable',
    };
  }

  /// Filtre les transactions par date
  List<Transaction> _filterTransactionsByDate(
    List<Transaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) {
      return transactions;
    }

    return transactions.where((transaction) {
      if (startDate != null && transaction.date.isBefore(startDate)) return false;
      if (endDate != null && transaction.date.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  /// Résumé financier complet
  Map<String, dynamic> getCompleteSummary(
    List<Transaction> transactions, {
    DateTime? startDate,
    DateTime? endDate,
    Map<String, double>? budgetLimits,
  }) {
    final typeStats = getTypeStats(transactions, startDate: startDate, endDate: endDate);
    final categoryStats = getCategoryStats(transactions, startDate: startDate, endDate: endDate);
    final topCategories = getTopCategories(transactions, startDate: startDate, endDate: endDate, limit: 5);
    final forecast = forecastNextMonth(transactions);
    final anomalies = detectAnomalies(transactions);

    return {
      'typeStats': typeStats,
      'categoryStats': categoryStats,
      'topCategories': topCategories,
      'forecast': forecast,
      'anomalies': anomalies.take(5).toList(),
      'summary': {
        'totalTransactions': transactions.length,
        'periodIncome': typeStats['income'],
        'periodExpense': typeStats['expense'],
        'balance': typeStats['balance'],
        'topCategory': topCategories.isNotEmpty ? topCategories[0]['category'] : 'N/A',
        'topCategoryAmount': topCategories.isNotEmpty ? topCategories[0]['amount'] : 0,
      },
    };
  }
}

extension on double {
  double sqrt() {
    return this < 0 ? 0 : double.parse((this ** 0.5).toStringAsFixed(2));
  }
}
