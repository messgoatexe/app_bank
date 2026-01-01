import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import 'db_service.dart';

class AccountsService {
  final _db = DBService.instance;
  static const _uuid = Uuid();

  // Créer un nouveau compte
  Future<AccountModel> createAccount({
    required String userId,
    required String name,
    required double initialBalance,
    String currency = 'EUR',
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      await _db.db.insert('accounts', {
        'id': id,
        'user_id': userId,
        'name': name,
        'balance': initialBalance,
        'currency': currency,
        'created_at': now.toIso8601String(),
      });

      return AccountModel(
        id: id,
        userId: userId,
        name: name,
        balance: initialBalance,
        currency: currency,
        createdAt: now,
      );
    } catch (e) {
      print('Error creating account: $e');
      rethrow;
    }
  }

  // Récupérer tous les comptes d'un utilisateur
  Future<List<AccountModel>> getUserAccounts(String userId) async {
    try {
      final maps = await _db.db.query(
        'accounts',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      return maps.map((m) => AccountModel.fromMap(m)).toList();
    } catch (e) {
      print('Error fetching accounts: $e');
      rethrow;
    }
  }

  // Récupérer un compte par ID
  Future<AccountModel?> getAccountById(String accountId) async {
    try {
      final maps = await _db.db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );

      if (maps.isEmpty) return null;
      return AccountModel.fromMap(maps.first);
    } catch (e) {
      print('Error fetching account: $e');
      rethrow;
    }
  }

  // Mettre à jour le solde d'un compte
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    try {
      await _db.db.update(
        'accounts',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    } catch (e) {
      print('Error updating account balance: $e');
      rethrow;
    }
  }

  // Renommer un compte
  Future<void> renameAccount(String accountId, String newName) async {
    try {
      await _db.db.update(
        'accounts',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [accountId],
      );
    } catch (e) {
      print('Error renaming account: $e');
      rethrow;
    }
  }

  // Supprimer un compte
  Future<void> deleteAccount(String accountId) async {
    try {
      await _db.db.delete(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  // Obtenir le solde total de tous les comptes d'un utilisateur
  Future<double> getTotalBalance(String userId) async {
    try {
      final accounts = await getUserAccounts(userId);
      double total = 0.0;
      for (final account in accounts) {
        total += account.balance;
      }
      return total;
    } catch (e) {
      print('Error calculating total balance: $e');
      rethrow;
    }
  }
}
