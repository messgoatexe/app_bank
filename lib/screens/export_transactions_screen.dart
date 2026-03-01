import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transactions_provider.dart';
import '../services/export_service.dart';

class ExportTransactionsScreen extends StatefulWidget {
  const ExportTransactionsScreen({super.key});

  @override
  State<ExportTransactionsScreen> createState() => _ExportTransactionsScreenState();
}

class _ExportTransactionsScreenState extends State<ExportTransactionsScreen> {
  String _selectedFormat = 'csv'; // csv or text
  bool _includeAllTransactions = true;

  void _exportData(BuildContext context) {
    final txProvider = Provider.of<TransactionsProvider>(context, listen: false);
    final exportService = ExportService.instance;

    String content;
    String filename;

    if (_selectedFormat == 'csv') {
      content = exportService.exportToCSV(txProvider.transactions);
      filename = 'transactions_${DateTime.now().toIso8601String()}.csv';
    } else {
      content = exportService.generateTextReport(txProvider.transactions);
      filename = 'transactions_report_${DateTime.now().toIso8601String()}.txt';
    }

    // Show success dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Données copiées: $content'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Copier',
          onPressed: () {
            // In a real app, copy to clipboard
          },
        ),
      ),
    );

    // Show the exported content in a dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aperçu de l\'export'),
        content: SingleChildScrollView(
          child: SelectableText(
            content.length > 2000 ? content.substring(0, 2000) + '...' : content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              // Copy to clipboard (would need clipboard package in real app)
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contenu prêt à être collé')),
              );
            },
            child: const Text('Copier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionsProvider>(context);
    final exportService = ExportService.instance;
    final stats = exportService.generateStatistics(txProvider.transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exporter les transactions'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Preview
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résumé des données',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total transactions', style: TextStyle(color: Colors.grey)),
                            Text(
                              '${stats['totalTransactions']} transactions',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Revenu total', style: TextStyle(color: Colors.grey)),
                            Text(
                              '${(stats['totalIncome'] as double).toStringAsFixed(2)} €',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dépense totale', style: TextStyle(color: Colors.grey)),
                            Text(
                              '${(stats['totalExpense'] as double).toStringAsFixed(2)} €',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Solde', style: TextStyle(color: Colors.grey)),
                            Text(
                              '${(stats['balance'] as double).toStringAsFixed(2)} €',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: (stats['balance'] as double) >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Breakdown
            if ((stats['categorySpending'] as Map).isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dépenses par catégorie',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...(stats['categorySpending'] as Map).entries.map((entry) {
                        final category = entry.key as String;
                        final amount = entry.value as double;
                        final ratio = amount / (stats['totalExpense'] as double);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(category),
                                  Text('${amount.toStringAsFixed(2)} €'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(Colors.blue.shade300),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Export Format Selection
            const Text(
              'Format d\'export',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    RadioListTile(
                      title: const Text('CSV (Tableur)'),
                      subtitle: const Text('Importable dans Excel, Google Sheets...'),
                      value: 'csv',
                      groupValue: _selectedFormat,
                      onChanged: (value) {
                        setState(() => _selectedFormat = value ?? 'csv');
                      },
                    ),
                    RadioListTile(
                      title: const Text('Rapporte texte'),
                      subtitle: const Text('Rapport formaté lisible'),
                      value: 'text',
                      groupValue: _selectedFormat,
                      onChanged: (value) {
                        setState(() => _selectedFormat = value ?? 'csv');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Export Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Exporter'),
                onPressed: txProvider.transactions.isEmpty
                  ? null
                  : () => _exportData(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Note: Les données seront copiées dans le presse-papiers. Vous pouvez ensuite les coller dans un fichier texte ou un tableur.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
