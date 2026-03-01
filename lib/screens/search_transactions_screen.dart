import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../services/transaction_search_service.dart';
import '../widgets/transaction_tile.dart';

class SearchTransactionsScreen extends StatefulWidget {
  const SearchTransactionsScreen({super.key});

  @override
  State<SearchTransactionsScreen> createState() => _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  List<TransactionModel> _results = [];
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _performSearch() {
    final txProvider = Provider.of<TransactionsProvider>(context, listen: false);
    final searchService = TransactionSearchService.instance;

    setState(() {
      _results = searchService.search(
        txProvider.transactions,
        query: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
        category: _selectedCategory,
        type: _selectedType,
        startDate: _startDate,
        endDate: _endDate,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedCategory = null;
      _selectedType = null;
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
      _results = [];
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionsProvider>(context);
    final searchService = TransactionSearchService.instance;
    final categories = searchService.getCategories(txProvider.transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chercher une transaction'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par description...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _performSearch();
                          },
                        )
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list),
                        label: Text(_showFilters ? 'Masquer' : 'Filtres'),
                        onPressed: () {
                          setState(() => _showFilters = !_showFilters);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Réinitialiser'),
                      onPressed: _clearFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters Section
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Filter
                  const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: _selectedCategory,
                    hint: const Text('Toutes les catégories'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes les catégories'),
                      ),
                      ...categories.map((cat) => DropdownMenuItem<String?>(
                        value: cat,
                        child: Text(cat),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      _performSearch();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Type Filter
                  const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Tous'),
                          selected: _selectedType == null,
                          onSelected: (_) {
                            setState(() => _selectedType = null);
                            _performSearch();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Revenu'),
                          selected: _selectedType == 'income',
                          onSelected: (_) {
                            setState(() => _selectedType = 'income');
                            _performSearch();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Dépense'),
                          selected: _selectedType == 'expense',
                          onSelected: (_) {
                            setState(() => _selectedType = 'expense');
                            _performSearch();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Range
                  const Text('Période', style: TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _startDate != null && _endDate != null
                        ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                        : 'Choisir une période',
                    ),
                    onPressed: _selectDateRange,
                  ),
                  const SizedBox(height: 16),

                  // Amount Range
                  const Text('Montant (€)', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Min',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _minAmount = double.tryParse(value);
                            _performSearch();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Max',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _maxAmount = double.tryParse(value);
                            _performSearch();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchCtrl.text.isEmpty && _selectedCategory == null && _selectedType == null && _startDate == null
                          ? 'Commence à chercher des transactions'
                          : 'Aucune transaction trouvée',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    return TransactionTile(transaction: _results[index]);
                  },
                ),
          ),

          // Results Counter
          if (_results.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.indigo.shade50,
              width: double.infinity,
              child: Text(
                '${_results.length} transaction${_results.length > 1 ? 's' : ''} trouvée${_results.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
