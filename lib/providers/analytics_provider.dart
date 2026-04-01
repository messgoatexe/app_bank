import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/analytics_service.dart';
import '../services/budget_insights_service.dart';

/// Provider pour les analytics et insights
class AnalyticsProvider with ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();
  final BudgetInsightsService _budgetInsightsService = BudgetInsightsService();

  List<Transaction> _transactions = [];
  Map<String, dynamic> _summary = {};
  List<BudgetInsight> _insights = [];
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  Map<String, dynamic> get summary => _summary;
  List<BudgetInsight> get insights => _insights;
  bool get isLoading => _isLoading;

  /// Met à jour les transactions analysées
  void updateTransactions(
    List<Transaction> transactions, {
    Map<String, double>? budgetLimits,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _isLoading = true;
    _transactions = transactions;
    notifyListeners();

    // Calculer le résumé complet
    _summary = _analyticsService.getCompleteSummary(
      transactions,
      startDate: startDate,
      endDate: endDate,
      budgetLimits: budgetLimits,
    );

    // Générer les insights
    _insights = _budgetInsightsService.generateInsights(
      transactions,
      budgetLimits: budgetLimits,
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Obtient les statistiques par catégorie
  Map<String, dynamic> getCategoryStats({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _analyticsService.getCategoryStats(
      _transactions,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Obtient les statistiques quotidiennes
  Map<String, dynamic> getDailyStats({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _analyticsService.getDailyStats(
      _transactions,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Obtient les statistiques par type
  Map<String, dynamic> getTypeStats({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _analyticsService.getTypeStats(
      _transactions,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Obtient les tendances mensuelles
  Map<String, dynamic> getMonthlyTrends() {
    return _analyticsService.getMonthlyTrends(_transactions);
  }

  /// Obtient les catégories principales
  List<Map<String, dynamic>> getTopCategories({
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _analyticsService.getTopCategories(
      _transactions,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Obtient les anomalies détectées
  List<Map<String, dynamic>> getAnomalies({
    double threshold = 2.0,
  }) {
    return _analyticsService.detectAnomalies(
      _transactions,
      threshold: threshold,
    );
  }

  /// Obtient la prévision pour le mois prochain
  Map<String, dynamic> getForecast() {
    return _analyticsService.forecastNextMonth(_transactions);
  }

  /// Obtient un conseil personnalisé pour économiser
  String getSavingsTip({Map<String, double>? budgetLimits}) {
    return _budgetInsightsService.generateSavingsTip(
      _transactions,
      budgetLimits: budgetLimits,
    );
  }

  /// Obtient les insights filtrés par priorité
  List<BudgetInsight> getInsightsByPriority(InsightPriority priority) {
    return _insights.where((i) => i.priority == priority).toList();
  }

  /// Réinitialise les données
  void clear() {
    _transactions = [];
    _summary = {};
    _insights = [];
    notifyListeners();
  }
}
