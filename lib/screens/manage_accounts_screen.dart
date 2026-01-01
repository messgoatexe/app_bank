import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounts_provider.dart';
import '../providers/auth_provider.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({Key? key}) : super(key: key);

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _selectedCurrency = 'EUR';

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _showAddAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un compte'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du compte'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Veuillez entrer un nom' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(labelText: 'Solde initial'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Veuillez entrer un solde';
                  if (double.tryParse(value!) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: _selectedCurrency,
                items: ['EUR', 'USD', 'GBP', 'CHF']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCurrency = value ?? 'EUR'),
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
                context.read<AccountsProvider>().createAccount(
                      userId: authProvider.user!.id,
                      name: _nameController.text,
                      initialBalance:
                          double.parse(_balanceController.text),
                      currency: _selectedCurrency,
                    );
                _nameController.clear();
                _balanceController.clear();
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
      appBar: AppBar(title: const Text('Mes comptes')),
      body: Consumer<AccountsProvider>(
        builder: (context, accountsProvider, _) {
          if (accountsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (accountsProvider.accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun compte créé'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddAccountDialog,
                    child: const Text('Créer un compte'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: accountsProvider.accounts.length,
            itemBuilder: (context, index) {
              final account = accountsProvider.accounts[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(account.name),
                  subtitle: Text('${account.balance} ${account.currency}'),
                  trailing: PopupMenuButton(
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
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer le compte ?'),
                            content: const Text(
                              'Êtes-vous sûr de vouloir supprimer ce compte ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () {
                                  accountsProvider.deleteAccount(account.id);
                                  Navigator.pop(context);
                                },
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
