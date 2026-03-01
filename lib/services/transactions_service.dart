import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/transaction_model.dart';
import 'db_service.dart';

class TransactionsService {
  TransactionsService._private();
  static final TransactionsService instance = TransactionsService._private();
  final _uuid = const Uuid();

  Future<List<TransactionModel>> getAll() async {
    try {
      final db = DBService.instance.db;
      final res = await db.query('transactions', orderBy: 'date DESC');
      return res.map((e) => TransactionModel.fromMap(e)).toList();
    } catch (e) {
      if (kIsWeb) {
        print('[TransactionsService] Web platform: returning empty list');
        return [];
      }
      rethrow;
    }
  }

  Future<List<TransactionModel>> getByUserId(String userId) async {
    try {
      final db = DBService.instance.db;
      final res = await db.query('transactions', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC');
      return res.map((e) => TransactionModel.fromMap(e)).toList();
    } catch (e) {
      if (kIsWeb) {
        print('[TransactionsService] Web platform: returning empty list');
        return [];
      }
      rethrow;
    }
  }

  Future<TransactionModel> create({
    required String userId,
    required double amount,
    required String type,
    required String category,
    String? description,
    required DateTime date,
  }) async {
    final id = _uuid.v4();
    final tx = TransactionModel(
      id: id,
      userId: userId,
      amount: amount,
      type: type,
      category: category,
      description: description,
      date: date,
    );
    try {
      await DBService.instance.db.insert('transactions', tx.toMap());
    } catch (e) {
      if (!kIsWeb) rethrow;
      print('[TransactionsService] Web platform: insert() no-op');
    }
    return tx;
  }

  Future<bool> update(TransactionModel tx) async {
    try {
      final count = await DBService.instance.db.update('transactions', tx.toMap(), where: 'id = ?', whereArgs: [tx.id]);
      return count == 1;
    } catch (e) {
      if (!kIsWeb) rethrow;
      print('[TransactionsService] Web platform: update() no-op');
      return true;
    }
  }

  Future<bool> delete(String id) async {
    try {
      final count = await DBService.instance.db.delete('transactions', where: 'id = ?', whereArgs: [id]);
      return count == 1;
    } catch (e) {
      if (!kIsWeb) rethrow;
      print('[TransactionsService] Web platform: delete() no-op');
      return true;
    }
  }
}
