import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionTile({super.key, required this.tx, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(tx.category[0].toUpperCase()),
        ),
        title: Text('${tx.category} — ${tx.description ?? ''}'),
        subtitle: Text(tx.formattedDate),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(2)} €', style: TextStyle(color: isIncome ? Colors.green : Colors.red)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, size: 18)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, size: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
