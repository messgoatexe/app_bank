import '../models/transaction_model.dart';
import 'analytics_service.dart';

/// Service pour générer des insights et recommandations budgétaires
class BudgetInsightsService {
  static final BudgetInsightsService _instance = BudgetInsightsService._internal();

  factory BudgetInsightsService() {
    return _instance;
  }

  BudgetInsightsService._internal();

  /// Génère une liste d'insights basés sur les données financières
  List<BudgetInsight> generateInsights(
    List<Transaction> transactions, {
    Map<String, double>? budgetLimits,
  }) {
    final insights = <BudgetInsight>[];
    final analyticsService = AnalyticsService();

    // Analyse des dépenses par rapport au budget
    if (budgetLimits != null) {
      insights.addAll(_analyzeBudgetOverspending(transactions, budgetLimits));
    }

    // Analyse des tendances de dépenses
    insights.addAll(_analyzeTrends(transactions, analyticsService));

    // Détection des catégories coûteuses
    insights.addAll(_detectExpensiveCategories(transactions, analyticsService));

    // Analyse du ratio revenus/dépenses
    insights.addAll(_analyzeIncomeExpenseRatio(transactions, analyticsService));

    // Détection des dépenses inhabituelles
    insights.addAll(_detectAnomalies(transactions, analyticsService));

    // Trier par priorité et score
    insights.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return insights;
  }

  /// Analyse les dépassements de budget
  List<BudgetInsight> _analyzeBudgetOverspending(
    List<Transaction> transactions,
    Map<String, double> budgetLimits,
  ) {
    final insights = <BudgetInsight>[];
    final analyticsService = AnalyticsService();
    final budgetAnalysis = analyticsService.getBudgetAnalysis(transactions, budgetLimits: budgetLimits);

    for (var category in budgetAnalysis.keys) {
      final analysis = budgetAnalysis[category] as Map<String, dynamic>;
      if (analysis['isExceeded'] as bool) {
        final exceeded = (analysis['spent'] as double) - (analysis['limit'] as double);
        insights.add(
          BudgetInsight(
            title: '⚠️ Budget dépassé: $category',
            description:
                'Vous avez dépensé ${exceeded.toStringAsFixed(2)}€ de plus que votre limite de ${(analysis['limit'] as double).toStringAsFixed(2)}€',
            priority: InsightPriority.high,
            type: InsightType.budgetOverspending,
            actionable: true,
            recommendation: 'Réduisez vos dépenses en $category ou augmentez votre limite budgétaire.',
          ),
        );
      } else if ((analysis['percentage'] as double) > 80) {
        insights.add(
          BudgetInsight(
            title: '📊 Attention: Approche limite en $category',
            description:
                'Vous avez utilisé ${(analysis['percentage'] as double).toStringAsFixed(1)}% de votre budget de $category',
            priority: InsightPriority.medium,
            type: InsightType.budgetWarning,
            actionable: true,
            recommendation: 'Vous approchez de votre limite. Soyez vigilant avec vos dépenses.',
          ),
        );
      }
    }

    return insights;
  }

  /// Analyse les tendances de dépenses
  List<BudgetInsight> _analyzeTrends(
    List<Transaction> transactions,
    AnalyticsService analyticsService,
  ) {
    final insights = <BudgetInsight>[];
    final forecast = analyticsService.forecastNextMonth(transactions);
    final trend = forecast['trend'] as String;

    if (trend == 'increasing') {
      insights.add(
        BudgetInsight(
          title: '📈 Tendance à la hausse détectée',
          description: 'Vos dépenses ont tendance à augmenter au fils des mois',
          priority: InsightPriority.medium,
          type: InsightType.spendingTrend,
          actionable: true,
          recommendation:
              'Vérifiez vos dépenses régulières et supprimez les abonnements inutiles si possible.',
        ),
      );
    } else if (trend == 'decreasing') {
      insights.add(
        BudgetInsight(
          title: '📉 Excellente tendance à la baisse',
          description: 'Vos dépenses diminuent au fil des mois - bon travail!',
          priority: InsightPriority.low,
          type: InsightType.positive,
          actionable: false,
          recommendation: 'Continuez à maintenir cette discipline budgétaire.',
        ),
      );
    }

    return insights;
  }

  /// Détecte les catégories coûteuses
  List<BudgetInsight> _detectExpensiveCategories(
    List<Transaction> transactions,
    AnalyticsService analyticsService,
  ) {
    final insights = <BudgetInsight>[];
    final topCategories = analyticsService.getTopCategories(transactions, limit: 3);

    if (topCategories.isNotEmpty) {
      final topCategory = topCategories.first;
      final percentage = topCategory['percentage'] as double;

      if (percentage > 30) {
        insights.add(
          BudgetInsight(
            title: '💰 ${topCategory['category']} est votre principales dépense',
            description:
                '${topCategory['category']} représente ${percentage.toStringAsFixed(1)}% de vos dépenses totales',
            priority: InsightPriority.medium,
            type: InsightType.categoryAnalysis,
            actionable: true,
            recommendation:
                'Évaluez si vous pouvez réduire cette catégorie ou si les dépenses sont justifiées.',
          ),
        );
      }
    }

    return insights;
  }

  /// Analyse le ratio revenus/dépenses
  List<BudgetInsight> _analyzeIncomeExpenseRatio(
    List<Transaction> transactions,
    AnalyticsService analyticsService,
  ) {
    final insights = <BudgetInsight>[];
    final typeStats = analyticsService.getTypeStats(transactions);
    final income = typeStats['income'] as double;
    final expense = typeStats['expense'] as double;
    final balance = typeStats['balance'] as double;

    if (income > 0) {
      final expenseRatio = (expense / income) * 100;

      if (expenseRatio > 90) {
        insights.add(
          BudgetInsight(
            title: '⚠️ Ratio dépenses/revenus critique',
            description:
                'Vous dépensez ${expenseRatio.toStringAsFixed(1)}% de vos revenus - peu d\'épargne',
            priority: InsightPriority.high,
            type: InsightType.ratioAnalysis,
            actionable: true,
            recommendation:
                'Essayez de réduire vos dépenses pour économiser au moins 20% de vos revenus.',
          ),
        );
      } else if (expenseRatio > 70) {
        insights.add(
          BudgetInsight(
            title: '📊 Ratio dépenses/revenus modéré',
            description:
                'Vous dépensez ${expenseRatio.toStringAsFixed(1)}% de vos revenus - marge limitée',
            priority: InsightPriority.medium,
            type: InsightType.ratioAnalysis,
            actionable: true,
            recommendation: 'Vous pourriez améliorer votre épargne en réduisant vos dépenses.',
          ),
        );
      } else if (balance > 0) {
        insights.add(
          BudgetInsight(
            title: '✅ Excellente gestion budgétaire',
            description: 'Vous économisez ${(balance).toStringAsFixed(2)}€ par période',
            priority: InsightPriority.low,
            type: InsightType.positive,
            actionable: false,
            recommendation: 'Continuez à économiser et envisagez d\'investir vos économies.',
          ),
        );
      }
    }

    return insights;
  }

  /// Détecte les dépenses inhabituelles
  List<BudgetInsight> _detectAnomalies(
    List<Transaction> transactions,
    AnalyticsService analyticsService,
  ) {
    final insights = <BudgetInsight>[];
    final anomalies = analyticsService.detectAnomalies(transactions);

    for (var anomaly in anomalies.take(3)) {
      insights.add(
        BudgetInsight(
          title: '🔔 Dépense inhabituelle détectée',
          description:
              'Le ${anomaly['date']} vous avez dépensé ${anomaly['amount'].toStringAsFixed(2)}€ (${anomaly['deviation']}% d\'écart)',
          priority: InsightPriority.low,
          type: InsightType.anomaly,
          actionable: true,
          recommendation: 'Vérifiez que cette dépense était intentionnelle.',
        ),
      );
    }

    return insights;
  }

  /// Génère une recommandation personnalisée pour augmenter l'épargne
  String generateSavingsTip(
    List<Transaction> transactions, {
    Map<String, double>? budgetLimits,
  }) {
    final analyticsService = AnalyticsService();
    final topCategories = analyticsService.getTopCategories(transactions, limit: 1);
    final typeStats = analyticsService.getTypeStats(transactions);

    if (topCategories.isEmpty) {
      return 'Commencez à enregistrer vos dépenses pour obtenir des conseils personnalisés.';
    }

    final topCategory = topCategories.first;
    final categoryName = topCategory['category'] as String;
    final categoryAmount = topCategory['amount'] as double;

    // Conseil basé sur la catégorie principale
    switch (categoryName.toLowerCase()) {
      case 'alimentation':
      case 'nourriture':
        return 'Réduisez vos dépenses alimentaires: planifiez vos repas et faites une liste de course.';
      case 'transport':
        return 'Optimisez vos trajets de transport: utilisez les transports publics quand possible.';
      case 'loisirs':
      case 'divertissement':
        return 'Limitez vos dépenses de loisirs: cherchez des activités gratuites ou moins coûteuses.';
      case 'shopping':
      case 'achats':
        return 'Attendez 30 jours avant les achats non essentiels pour éviter les impulsions.';
      case 'abonnements':
      case 'services':
        return 'Auditez vos abonnements: annulez ceux que vous n\'utilisez pas vraiment.';
      default:
        final savings = (categoryAmount * 0.1).toStringAsFixed(2);
        return 'Réduire $categoryName de 10% vous économiserait $savings€ par mois!';
    }
  }
}

/// Modèle pour un insight budgétaire
class BudgetInsight {
  final String title;
  final String description;
  final InsightPriority priority;
  final InsightType type;
  final bool actionable;
  final String recommendation;
  final DateTime createdAt;

  BudgetInsight({
    required this.title,
    required this.description,
    required this.priority,
    required this.type,
    required this.actionable,
    required this.recommendation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get icon {
    switch (type) {
      case InsightType.budgetOverspending:
        return '⚠️';
      case InsightType.budgetWarning:
        return '📊';
      case InsightType.spendingTrend:
        return '📈';
      case InsightType.categoryAnalysis:
        return '💰';
      case InsightType.ratioAnalysis:
        return '📊';
      case InsightType.anomaly:
        return '🔔';
      case InsightType.positive:
        return '✅';
    }
  }
}

/// Priorité de l'insight
enum InsightPriority {
  low,
  medium,
  high,
}

/// Type d'insight
enum InsightType {
  budgetOverspending,
  budgetWarning,
  spendingTrend,
  categoryAnalysis,
  ratioAnalysis,
  anomaly,
  positive,
}
