import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../providers/transactions_provider.dart';

/// Écran pour afficher les analytics avancées et les statistiques financières
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime? startDate;
  DateTime? endDate;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnalytics();
  }

  void _initializeAnalytics() {
    final transactionsProvider = context.read<TransactionsProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();
    
    analyticsProvider.updateTransactions(
      transactionsProvider.transactions,
      budgetLimits: await _getBudgetLimits(), // À implémenter
    );
  }

  Future<Map<String, double>?> _getBudgetLimits() async {
    // À implémenter: récupérer les limites budgétaires
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vue d\'ensemble'),
              Tab(text: 'Catégories'),
              Tab(text: 'Tendances'),
              Tab(text: 'Insights'),
            ],
          ),
        ),
        body: Consumer<AnalyticsProvider>(
          builder: (context, analyticsProvider, _) {
            if (analyticsProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              children: [
                _buildOverviewTab(analyticsProvider),
                _buildCategoriesTab(analyticsProvider),
                _buildTrendsTab(analyticsProvider),
                _buildInsightsTab(analyticsProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Onglet Vue d'ensemble
  Widget _buildOverviewTab(AnalyticsProvider provider) {
    final summary = provider.summary;
    if (summary.isEmpty) {
      return Center(
        child: Text(
          'Aucune données disponible',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final typeStats = summary['typeStats'] as Map<String, dynamic>;
    final income = typeStats['income'] as double;
    final expense = typeStats['expense'] as double;
    final balance = typeStats['balance'] as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartes de synthèse
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Revenus',
                  amount: income,
                  color: Colors.green,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Dépenses',
                  amount: expense,
                  color: Colors.red,
                  icon: Icons.trending_down,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Solde',
                  amount: balance,
                  color: balance >= 0 ? Colors.blue : Colors.orange,
                  icon: Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Transactions',
                  amount: (summary['summary'] as Map)['totalTransactions'].toDouble(),
                  color: Colors.purple,
                  icon: Icons.receipt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Ratio revenus/dépenses
          Text(
            'Ratio Revenus/Dépenses',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          _buildRatioChart(
            income: income,
            expense: expense,
          ),
          const SizedBox(height: 24),

          // Prévisions
          Text(
            'Prévisions Mois Prochain',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          _buildForecastCard(provider),
        ],
      ),
    );
  }

  /// Onglet Catégories
  Widget _buildCategoriesTab(AnalyticsProvider provider) {
    final topCategories = provider.getTopCategories(limit: 10);

    if (topCategories.isEmpty) {
      return Center(
        child: Text(
          'Aucune catégorie',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Catégories',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          _buildCategoriesPieChart(topCategories),
          const SizedBox(height: 24),
          ...[
            for (var i = 0; i < topCategories.length; i++)
              _buildCategoryItem(topCategories[i], i + 1)
          ],
        ],
      ),
    );
  }

  /// Onglet Tendances
  Widget _buildTrendsTab(AnalyticsProvider provider) {
    final monthlyTrends = provider.getMonthlyTrends();
    final monthlyExpense = monthlyTrends['monthlyExpense'] as Map<String, double>;

    if (monthlyExpense.isEmpty) {
      return Center(
        child: Text(
          'Pas assez de données mensuelles',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendances Mensuelles',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          _buildLineChart(monthlyExpense),
          const SizedBox(height: 24),
          Text(
            'Détails Mensuels',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          ...[
            for (var entry in monthlyExpense.entries)
              _buildMonthItem(entry.key, entry.value)
          ],
        ],
      ),
    );
  }

  /// Onglet Insights
  Widget _buildInsightsTab(AnalyticsProvider provider) {
    final insights = provider.insights;

    if (insights.isEmpty) {
      return Center(
        child: Text(
          'Aucun insight disponible',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conseil personnalisé
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Conseil pour Économiser',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.getSavingsTip(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Insights Détaillés',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          ...[
            for (var insight in insights) _buildInsightCard(insight)
          ],
        ],
      ),
    );
  }

  // Widgets auxiliaires

  Widget _buildStatCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${amount.toStringAsFixed(2)}€',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatioChart({
    required double income,
    required double expense,
  }) {
    final total = income + expense;
    final incomeRatio = total > 0 ? income / total : 0;
    final expenseRatio = total > 0 ? expense / total : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: incomeRatio * 100,
                        color: Colors.green,
                        title: '${(incomeRatio * 100).toStringAsFixed(1)}%',
                      ),
                      PieChartSectionData(
                        value: expenseRatio * 100,
                        color: Colors.red,
                        title: '${(expenseRatio * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text('Revenus: ${income.toStringAsFixed(2)}€'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text('Dépenses: ${expense.toStringAsFixed(2)}€'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesPieChart(List<Map<String, dynamic>> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: [
                for (var i = 0; i < categories.length && i < 5; i++)
                  PieChartSectionData(
                    value: categories[i]['percentage'] as double,
                    color: [
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.red,
                      Colors.purple,
                    ][i % 5],
                    title: '${(categories[i]['percentage'] as double).toStringAsFixed(1)}%',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<String, double> monthlyData) {
    final entries = monthlyData.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: const FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < entries.length; i++)
                      FlSpot(i.toDouble(), entries[i].value)
                  ],
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category, int rank) {
    final percentage = category['percentage'] as double;
    final amount = category['amount'] as double;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Text('$rank'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['category'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${amount.toStringAsFixed(2)}€',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthItem(String month, double amount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(month),
        trailing: Text(
          '${amount.toStringAsFixed(2)}€',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInsightCard(BudgetInsight insight) {
    final priorityColor = insight.priority == InsightPriority.high
        ? Colors.red
        : insight.priority == InsightPriority.medium
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: priorityColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                insight.description,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '💡 ${insight.recommendation}',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastCard(AnalyticsProvider provider) {
    final forecast = provider.getForecast();
    final forecastedExpense = forecast['forecastedExpense'] as double;
    final forecastedBalance = forecast['forecastedBalance'] as double;
    final trend = forecast['trend'] as String;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dépenses Prévues',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${forecastedExpense.toStringAsFixed(2)}€',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tendance',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trend == 'increasing'
                          ? '📈 À la hausse'
                          : trend == 'decreasing'
                              ? '📉 À la baisse'
                              : '➡️ Stable',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
