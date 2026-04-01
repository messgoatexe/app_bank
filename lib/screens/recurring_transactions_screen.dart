import 'package:flutter/material.dart';
import '../services/recurring_transactions_service.dart';
import '../models/transaction_model.dart';

/// Écran pour gérer les transactions récurrentes
class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  final RecurringTransactionsService _service = RecurringTransactionsService();
  late List<RecurringTransaction> _recurringTransactions;

  @override
  void initState() {
    super.initState();
    _loadRecurringTransactions();
  }

  void _loadRecurringTransactions() {
    setState(() {
      _recurringTransactions = _service.getAllRecurringTransactions();
    });
  }

  void _showAddDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    var selectedCategory = 'Autres';
    var selectedFrequency = RecurrenceFrequency.monthly;
    var startDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une Transaction Récurrente'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Ex: Loyer, Abonnement Netflix',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Montant (€)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: const [
                    'Autres',
                    'Logement',
                    'Alimentation',
                    'Transport',
                    'Abonnements',
                    'Loisirs',
                  ]
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedCategory = value ?? 'Autres');
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RecurrenceFrequency>(
                  value: selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Fréquence'),
                  items: RecurrenceFrequency.values
                      .map(
                        (freq) => DropdownMenuItem(
                          value: freq,
                          child: Text(_frequencyLabel(freq)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedFrequency = value ?? RecurrenceFrequency.monthly);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date de début'),
                  subtitle: Text(startDate.toLocal().toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => startDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final description = descriptionController.text;
              final amount = double.tryParse(amountController.text) ?? 0;

              if (description.isEmpty || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez remplir tous les champs')),
                );
                return;
              }

              final recurring = RecurringTransaction(
                description: description,
                amount: amount,
                category: selectedCategory,
                frequency: selectedFrequency,
                startDate: startDate,
              );

              _service.addRecurringTransaction(recurring);
              _loadRecurringTransactions();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction récurrente ajoutée')),
              );
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _toggleRecurring(RecurringTransaction recurring) {
    _service.updateRecurringTransaction(
      recurring.copyWith(isActive: !recurring.isActive),
    );
    _loadRecurringTransactions();
  }

  void _deleteRecurring(String id) {
    _service.deleteRecurringTransaction(id);
    _loadRecurringTransactions();
  }

  String _frequencyLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return 'Quotidienne';
      case RecurrenceFrequency.weekly:
        return 'Hebdomadaire';
      case RecurrenceFrequency.biWeekly:
        return 'Bi-hebdomadaire';
      case RecurrenceFrequency.monthly:
        return 'Mensuelle';
      case RecurrenceFrequency.quarterly:
        return 'Trimestrielle';
      case RecurrenceFrequency.semiAnnually:
        return 'Semestrielle';
      case RecurrenceFrequency.annually:
        return 'Annuelle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _recurringTransactions.where((t) => t.isActive).length;
    final total = _recurringTransactions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔄 Transactions Récurrentes'),
        elevation: 0,
      ),
      body: _recurringTransactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucune transaction récurrente'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Résumé
                  Container(
                    color: Colors.blue.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(height: 4),
                            Text('$active Actives'),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.schedule, color: Colors.blue),
                            const SizedBox(height: 4),
                            Text('$total Total'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Liste des transactions récurrentes
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recurringTransactions.length,
                    itemBuilder: (context, index) {
                      final recurring = _recurringTransactions[index];
                      final nextDate = _service.getNextExecutionDate(recurring);
                      final daysUntil = _service.getDaysUntilExecution(recurring);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: recurring.isActive,
                            onChanged: (_) => _toggleRecurring(recurring),
                          ),
                          title: Text(recurring.description),
                          subtitle: Text(
                            '${_frequencyLabel(recurring.frequency)} • ${recurring.category}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Text('Supprimer'),
                                onTap: () => _deleteRecurring(recurring.id),
                              ),
                            ],
                          ),
                          onTap: () {
                            // Vous pouvez ouvrir un détail si nécessaire
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
