import 'package:flutter/material.dart';
import '../models/account_model.dart';
import '../services/accounts_service.dart';

class AccountsProvider extends ChangeNotifier {
  final AccountsService _accountsService = AccountsService();
  
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  bool _isLoading = false;
  String? _error;

  List<AccountModel> get accounts => _accounts;
  AccountModel? get selectedAccount => _selectedAccount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserAccounts(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await _accountsService.getUserAccounts(userId);
      if (_accounts.isNotEmpty && _selectedAccount == null) {
        _selectedAccount = _accounts.first;
      }
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> createAccount({
    required String userId,
    required String name,
    required double initialBalance,
    String currency = 'EUR',
  }) async {
    try {
      final newAccount = await _accountsService.createAccount(
        userId: userId,
        name: name,
        initialBalance: initialBalance,
        currency: currency,
      );
      _accounts.add(newAccount);
      if (_selectedAccount == null) {
        _selectedAccount = newAccount;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    try {
      await _accountsService.updateAccountBalance(accountId, newBalance);
      final index = _accounts.indexWhere((a) => a.id == accountId);
      if (index != -1) {
        _accounts[index] = AccountModel(
          id: _accounts[index].id,
          userId: _accounts[index].userId,
          name: _accounts[index].name,
          balance: newBalance,
          currency: _accounts[index].currency,
          createdAt: _accounts[index].createdAt,
        );
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> renameAccount(String accountId, String newName) async {
    try {
      await _accountsService.renameAccount(accountId, newName);
      final index = _accounts.indexWhere((a) => a.id == accountId);
      if (index != -1) {
        _accounts[index] = AccountModel(
          id: _accounts[index].id,
          userId: _accounts[index].userId,
          name: newName,
          balance: _accounts[index].balance,
          currency: _accounts[index].currency,
          createdAt: _accounts[index].createdAt,
        );
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      await _accountsService.deleteAccount(accountId);
      _accounts.removeWhere((a) => a.id == accountId);
      if (_selectedAccount?.id == accountId) {
        _selectedAccount = _accounts.isNotEmpty ? _accounts.first : null;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  void selectAccount(AccountModel account) {
    _selectedAccount = account;
    notifyListeners();
  }

  Future<double> getTotalBalance(String userId) async {
    try {
      return await _accountsService.getTotalBalance(userId);
    } catch (e) {
      _error = e.toString();
      return 0.0;
    }
  }
}
