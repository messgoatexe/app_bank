import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import 'add_edit_transaction_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'search_transactions_screen.dart';
import 'export_transactions_screen.dart';
import '../widgets/transaction_tile.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    // Récupérer l'ID utilisateur et charger les transactions
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final txProvider = Provider.of<TransactionsProvider>(context, listen: false);
      txProvider.setUserId(authProvider.user!.id);
      txProvider.load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionsProvider>(context);

    double balance() {
      double income = 0, expense = 0;
      for (var t in txProvider.transactions) {
        if (t.type == 'income') income += t.amount;
        else expense += t.amount;
      }
      return income - expense;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Bancaire'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.home),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.receipt),
              text: 'Transactions',
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchTransactionsScreen())),
            icon: const Icon(Icons.search),
            tooltip: 'Chercher une transaction',
          ),
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'export') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportTransactionsScreen()));
              } else if (result == 'profile') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Exporter'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle, size: 20),
                    SizedBox(width: 8),
                    Text('Profil'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditTransactionScreen())).then((_) => setState(() {})),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet Dashboard
          const DashboardScreen(),

          // Onglet Transactions
          RefreshIndicator(
            onRefresh: () => txProvider.load(),
            child: Column(
              children: [
                Container(
                  color: Colors.indigo.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Solde courant', style: TextStyle(fontSize: 16)),
                      Text('${balance().toStringAsFixed(2)} €', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: txProvider.transactions.isEmpty
                      ? const Center(child: Text('Aucune transaction. Ajoute-en une.'))
                      : ListView.builder(
                          itemCount: txProvider.transactions.length,
                          itemBuilder: (context, i) {
                            final t = txProvider.transactions[i];
                            return TransactionTile(
                              tx: t,
                              onEdit: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEditTransactionScreen(editTx: t))).then((_) => setState(() {})),
                              onDelete: () async {
                                await txProvider.remove(t.id);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction supprimée')));
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
