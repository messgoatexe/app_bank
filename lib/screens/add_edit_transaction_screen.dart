import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final TransactionModel? editTx;
  const AddEditTransactionScreen({super.key, this.editTx});

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'expense';
  String _category = 'Autres';
  DateTime _date = DateTime.now();
  bool _loading = false;

  final _categories = ['Alimentation', 'Logement', 'Transport', 'Loisirs', 'Salaire', 'Autres'];

  @override
  void initState() {
    super.initState();
    final t = widget.editTx;
    if (t != null) {
      _amountCtrl.text = t.amount.toString();
      _descCtrl.text = t.description ?? '';
      _type = t.type;
      _category = t.category;
      _date = t.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionsProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: Text(widget.editTx == null ? 'Ajouter une transaction' : 'Modifier la transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Montant (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => v == null || double.tryParse(v) == null ? 'Montant invalide' : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Dépense')),
                DropdownMenuItem(value: 'income', child: Text('Revenu')),
              ],
              onChanged: (v) => setState(() { _type = v ?? 'expense'; }),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() { _category = v ?? 'Autres'; }),
              decoration: const InputDecoration(labelText: 'Catégorie'),
            ),
            const SizedBox(height: 8),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description (optionnelle)')),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Date : ${_date.toLocal().toString().split(' ')[0]}'),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _date = picked);
                }, child: const Text('Choisir')),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : () async {
                if (!_formKey.currentState!.validate()) return;
                setState(() { _loading = true; });
                final amount = double.parse(_amountCtrl.text);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final userId = authProvider.user?.id ?? '';
                
                if (widget.editTx == null) {
                  await txProvider.add(TransactionModel(
                    id: '', // ignored by provider.create
                    userId: userId,
                    amount: amount,
                    type: _type,
                    category: _category,
                    description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
                    date: _date,
                  ));
                } else {
                  final updated = TransactionModel(
                    id: widget.editTx!.id,
                    userId: userId,
                    amount: amount,
                    type: _type,
                    category: _category,
                    description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
                    date: _date,
                  );
                  await txProvider.update(updated);
                }
                setState(() { _loading = false; });
                Navigator.of(context).pop();
              },
              child: _loading ? const CircularProgressIndicator() : Text(widget.editTx == null ? 'Ajouter' : 'Enregistrer'),
            )
          ]),
        ),
      ),
    );
  }
}
