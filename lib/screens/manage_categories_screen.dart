import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/categories_provider.dart';
import '../providers/auth_provider.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedColor = '#FF5722';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une catégorie'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Dépense')),
                  DropdownMenuItem(value: 'income', child: Text('Revenu')),
                ]
                    .map((item) => item)
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedType = value ?? 'expense'),
              ),
            ],
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
                context.read<CategoriesProvider>().createCategory(
                      userId: authProvider.user!.id,
                      name: _nameController.text,
                      type: _selectedType,
                      color: _selectedColor,
                    );
                _nameController.clear();
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
      appBar: AppBar(title: const Text('Mes catégories')),
      body: Consumer<CategoriesProvider>(
        builder: (context, categoriesProvider, _) {
          if (categoriesProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = categoriesProvider.categories
              .where((c) => c.type == 'expense')
              .toList();
          final incomes = categoriesProvider.categories
              .where((c) => c.type == 'income')
              .toList();

          return ListView(
            children: [
              if (expenses.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Dépenses',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...expenses.map((category) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(
                              category.color?.replaceFirst('#', '0x') ??
                                  '0xFFFF5722',
                            ),
                          ),
                          child: const Icon(Icons.category, color: Colors.white),
                        ),
                        title: Text(category.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer la catégorie ?'),
                                content: const Text(
                                  'Êtes-vous sûr de vouloir supprimer cette catégorie ?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      categoriesProvider
                                          .deleteCategory(category.id);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ))
              ],
              if (incomes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Revenus',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...incomes.map((category) => Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            int.parse(
                              category.color?.replaceFirst('#', '0x') ??
                                  '0xFF4CAF50',
                            ),
                          ),
                          child: const Icon(Icons.category, color: Colors.white),
                        ),
                        title: Text(category.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer la catégorie ?'),
                                content: const Text(
                                  'Êtes-vous sûr de vouloir supprimer cette catégorie ?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      categoriesProvider
                                          .deleteCategory(category.id);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ))
              ],
              if (expenses.isEmpty && incomes.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Aucune catégorie personnalisée'),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
