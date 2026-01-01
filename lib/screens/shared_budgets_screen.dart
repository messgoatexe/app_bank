import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shared_budgets_provider.dart';
import '../providers/auth_provider.dart';

class SharedBudgetsScreen extends StatefulWidget {
  const SharedBudgetsScreen({Key? key}) : super(key: key);

  @override
  State<SharedBudgetsScreen> createState() => _SharedBudgetsScreenState();
}

class _SharedBudgetsScreenState extends State<SharedBudgetsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showCreateBudgetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer un budget partagé'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom du budget'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Veuillez entrer un nom' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limitController,
                  decoration:
                      const InputDecoration(labelText: 'Limite mensuelle'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Veuillez entrer une limite';
                    if (double.tryParse(value!) == null) {
                      return 'Veuillez entrer un nombre valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Description (optionnel)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ajouter des membres (emails)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // TODO: Implémenter un système d'ajout de membres par email
                const Text(
                  'Fonctionnalité en développement',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final authProvider = context.read<AuthProvider>();
                context.read<SharedBudgetsProvider>().createSharedBudget(
                      ownerUserId: authProvider.user!.id,
                      name: _nameController.text,
                      monthlyLimit: double.parse(_limitController.text),
                      memberUserIds: [authProvider.user!.id],
                      description: _descriptionController.text.isEmpty
                          ? null
                          : _descriptionController.text,
                    );
                _nameController.clear();
                _limitController.clear();
                _descriptionController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets partagés')),
      body: Consumer<SharedBudgetsProvider>(
        builder: (context, budgetsProvider, _) {
          if (budgetsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (budgetsProvider.budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun budget partagé'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showCreateBudgetDialog,
                    child: const Text('Créer un budget'),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<void>(
            future: Future.wait(
              budgetsProvider.budgets.map((b) async {
                await budgetsProvider.getMonthlyBudgetSpending(b.id);
              }),
            ),
            builder: (context, snapshot) {
              return ListView.builder(
                itemCount: budgetsProvider.budgets.length,
                itemBuilder: (context, index) {
                  final budget = budgetsProvider.budgets[index];
                  final members = budgetsProvider.getBudgetMembers(budget.id);

                  return FutureBuilder<double>(
                    future:
                        budgetsProvider.getMonthlyBudgetSpending(budget.id),
                    builder: (context, spendingSnapshot) {
                      final spending =
                          spendingSnapshot.data ?? 0.0;
                      final percentage =
                          (spending / budget.monthlyLimit * 100).clamp(0, 100);

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          budget.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${members.length} membre(s)',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Modifier'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Supprimer'),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (context) =>
                                              AlertDialog(
                                                title: const Text(
                                                  'Supprimer le budget ?',
                                                ),
                                                content: const Text(
                                                  'Êtes-vous sûr de vouloir supprimer ce budget ?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child:
                                                        const Text('Annuler'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      budgetsProvider
                                                          .deleteSharedBudget(
                                                        budget.id,
                                                      );
                                                      Navigator.pop(context);
                                                    },
                                                    child:
                                                        const Text('Supprimer'),
                                                  ),
                                                ],
                                              ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: percentage / 100,
                                color: percentage > 100
                                    ? Colors.red
                                    : percentage > 80
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${spending.toStringAsFixed(2)} / ${budget.monthlyLimit.toStringAsFixed(2)} €',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${percentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: percentage > 100
                                          ? Colors.red
                                          : percentage > 80
                                              ? Colors.orange
                                              : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
