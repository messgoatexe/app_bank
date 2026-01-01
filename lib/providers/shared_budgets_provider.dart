import 'package:flutter/material.dart';
import '../models/shared_budget_model.dart';
import '../services/shared_budgets_service.dart';

class SharedBudgetsProvider extends ChangeNotifier {
  final SharedBudgetsService _sharedBudgetsService = SharedBudgetsService();
  
  List<SharedBudgetModel> _budgets = [];
  SharedBudgetModel? _selectedBudget;
  Map<String, List<BudgetMemberModel>> _budgetMembers = {};
  bool _isLoading = false;
  String? _error;

  List<SharedBudgetModel> get budgets => _budgets;
  SharedBudgetModel? get selectedBudget => _selectedBudget;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BudgetMemberModel> getBudgetMembers(String budgetId) {
    return _budgetMembers[budgetId] ?? [];
  }

  Future<void> loadUserBudgets(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _budgets = await _sharedBudgetsService.getUserSharedBudgets(userId);
      
      // Charger les membres pour chaque budget
      for (final budget in _budgets) {
        _budgetMembers[budget.id] =
            await _sharedBudgetsService.getBudgetMembers(budget.id);
      }
      
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> createSharedBudget({
    required String ownerUserId,
    required String name,
    required double monthlyLimit,
    required List<String> memberUserIds,
    String? description,
  }) async {
    try {
      final newBudget = await _sharedBudgetsService.createSharedBudget(
        ownerUserId: ownerUserId,
        name: name,
        monthlyLimit: monthlyLimit,
        memberUserIds: memberUserIds,
        description: description,
      );
      _budgets.add(newBudget);
      
      // Charger les membres du nouveau budget
      _budgetMembers[newBudget.id] =
          await _sharedBudgetsService.getBudgetMembers(newBudget.id);
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> addMemberToBudget(String budgetId, String userId) async {
    try {
      await _sharedBudgetsService.addMemberToBudget(budgetId, userId);
      _budgetMembers[budgetId] =
          await _sharedBudgetsService.getBudgetMembers(budgetId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeMemberFromBudget(String budgetId, String userId) async {
    try {
      await _sharedBudgetsService.removeMemberFromBudget(budgetId, userId);
      _budgetMembers[budgetId] =
          await _sharedBudgetsService.getBudgetMembers(budgetId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateSharedBudget(
    String budgetId, {
    String? name,
    double? monthlyLimit,
    String? description,
  }) async {
    try {
      await _sharedBudgetsService.updateSharedBudget(
        budgetId,
        name: name,
        monthlyLimit: monthlyLimit,
        description: description,
      );
      final budget = await _sharedBudgetsService.getBudgetById(budgetId);
      if (budget != null) {
        final index = _budgets.indexWhere((b) => b.id == budgetId);
        if (index != -1) {
          _budgets[index] = budget;
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteSharedBudget(String budgetId) async {
    try {
      await _sharedBudgetsService.deleteSharedBudget(budgetId);
      _budgets.removeWhere((b) => b.id == budgetId);
      _budgetMembers.remove(budgetId);
      if (_selectedBudget?.id == budgetId) {
        _selectedBudget = null;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<double> getMonthlyBudgetSpending(String budgetId) async {
    try {
      return await _sharedBudgetsService.getMonthlyBudgetSpending(budgetId);
    } catch (e) {
      _error = e.toString();
      return 0.0;
    }
  }

  Future<bool> isBudgetExceeded(String budgetId) async {
    try {
      return await _sharedBudgetsService.isBudgetExceeded(budgetId);
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  void selectBudget(SharedBudgetModel budget) {
    _selectedBudget = budget;
    notifyListeners();
  }
}
