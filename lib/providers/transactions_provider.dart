import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/transactions_service.dart';

class TransactionsProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  String? _userId;

  List<TransactionModel> get transactions => _transactions;

  void setUserId(String userId) {
    _userId = userId;
  }

  Future<void> load() async {
    if (_userId == null) return;
    _transactions = await TransactionsService.instance.getByUserId(_userId!);
    notifyListeners();
  }

  Future<void> add(TransactionModel tx) async {
    if (_userId == null) return;
    await TransactionsService.instance.create(
      userId: _userId!,
      amount: tx.amount,
      type: tx.type,
      category: tx.category,
      description: tx.description,
      date: tx.date,
    );
    await load();
  }

  Future<void> update(TransactionModel tx) async {
    await TransactionsService.instance.update(tx);
    await load();
  }

  Future<void> remove(String id) async {
    await TransactionsService.instance.delete(id);
    await load();
  }
}
