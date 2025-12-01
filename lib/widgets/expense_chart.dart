import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class ExpenseChart extends StatelessWidget {
  final List<TransactionModel> transactions;

  const ExpenseChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Calculer les dépenses par catégorie
    final expensesByCategory = <String, double>{};
    for (var tx in transactions) {
      if (tx.type == 'expense') {
        expensesByCategory[tx.category] = (expensesByCategory[tx.category] ?? 0) + tx.amount;
      }
    }

    if (expensesByCategory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune dépense à afficher', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    final colors = [Colors.red, Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.teal];
    final entries = expensesByCategory.entries.toList();

    // Créer un graphique en barres simple
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Dépenses par catégorie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value.key;
                final amount = entry.value.value;
                final color = colors[index % colors.length];
                final maxAmount = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
                final barWidth = (amount / maxAmount) * 250;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('${amount.toStringAsFixed(2)}€', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 20,
                          width: barWidth,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
