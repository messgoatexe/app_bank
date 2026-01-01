import 'package:uuid/uuid.dart';
import '../models/shared_budget_model.dart';
import 'db_service.dart';

class SharedBudgetsService {
  final _db = DBService.instance;
  static const _uuid = Uuid();

  // Créer un budget partagé
  Future<SharedBudgetModel> createSharedBudget({
    required String ownerUserId,
    required String name,
    required double monthlyLimit,
    required List<String> memberUserIds,
    String? description,
  }) async {
    try {
      final budgetId = _uuid.v4();
      final now = DateTime.now();

      // Créer le budget
      await _db.db.insert('shared_budgets', {
        'id': budgetId,
        'name': name,
        'monthly_limit': monthlyLimit,
        'description': description,
        'created_at': now.toIso8601String(),
      });

      // Ajouter le propriétaire comme membre
      await _db.db.insert('budget_members', {
        'budget_id': budgetId,
        'user_id': ownerUserId,
        'role': 'owner',
        'joined_at': now.toIso8601String(),
      });

      // Ajouter les autres membres
      for (final userId in memberUserIds) {
        if (userId != ownerUserId) {
          await _db.db.insert('budget_members', {
            'budget_id': budgetId,
            'user_id': userId,
            'role': 'member',
            'joined_at': now.toIso8601String(),
          });
        }
      }

      return SharedBudgetModel(
        id: budgetId,
        name: name,
        monthlyLimit: monthlyLimit,
        userIds: [ownerUserId, ...memberUserIds],
        description: description,
        createdAt: now,
      );
    } catch (e) {
      print('Error creating shared budget: $e');
      rethrow;
    }
  }

  // Récupérer tous les budgets partagés d'un utilisateur
  Future<List<SharedBudgetModel>> getUserSharedBudgets(String userId) async {
    try {
      final maps = await _db.db.rawQuery('''
        SELECT sb.* FROM shared_budgets sb
        INNER JOIN budget_members bm ON sb.id = bm.budget_id
        WHERE bm.user_id = ?
        ORDER BY sb.created_at DESC
      ''', [userId]);

      return maps.map((m) => SharedBudgetModel.fromMap(m)).toList();
    } catch (e) {
      print('Error fetching user shared budgets: $e');
      rethrow;
    }
  }

  // Récupérer un budget par ID
  Future<SharedBudgetModel?> getBudgetById(String budgetId) async {
    try {
      final maps = await _db.db.query(
        'shared_budgets',
        where: 'id = ?',
        whereArgs: [budgetId],
      );

      if (maps.isEmpty) return null;
      return SharedBudgetModel.fromMap(maps.first);
    } catch (e) {
      print('Error fetching budget: $e');
      rethrow;
    }
  }

  // Obtenir les membres d'un budget partagé
  Future<List<BudgetMemberModel>> getBudgetMembers(String budgetId) async {
    try {
      final maps = await _db.db.query(
        'budget_members',
        where: 'budget_id = ?',
        whereArgs: [budgetId],
        orderBy: 'joined_at ASC',
      );

      return maps.map((m) => BudgetMemberModel.fromMap(m)).toList();
    } catch (e) {
      print('Error fetching budget members: $e');
      rethrow;
    }
  }

  // Ajouter un membre à un budget partagé
  Future<void> addMemberToBudget(
    String budgetId,
    String userId,
  ) async {
    try {
      await _db.db.insert('budget_members', {
        'budget_id': budgetId,
        'user_id': userId,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding member to budget: $e');
      rethrow;
    }
  }

  // Retirer un membre d'un budget partagé
  Future<void> removeMemberFromBudget(String budgetId, String userId) async {
    try {
      await _db.db.delete(
        'budget_members',
        where: 'budget_id = ? AND user_id = ?',
        whereArgs: [budgetId, userId],
      );
    } catch (e) {
      print('Error removing member from budget: $e');
      rethrow;
    }
  }

  // Mettre à jour un budget partagé
  Future<void> updateSharedBudget(
    String budgetId, {
    String? name,
    double? monthlyLimit,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (monthlyLimit != null) updateData['monthly_limit'] = monthlyLimit;
      if (description != null) updateData['description'] = description;

      if (updateData.isNotEmpty) {
        await _db.db.update(
          'shared_budgets',
          updateData,
          where: 'id = ?',
          whereArgs: [budgetId],
        );
      }
    } catch (e) {
      print('Error updating shared budget: $e');
      rethrow;
    }
  }

  // Supprimer un budget partagé
  Future<void> deleteSharedBudget(String budgetId) async {
    try {
      // Supprimer les membres en premier (contrainte FK)
      await _db.db.delete(
        'budget_members',
        where: 'budget_id = ?',
        whereArgs: [budgetId],
      );

      // Puis supprimer le budget
      await _db.db.delete(
        'shared_budgets',
        where: 'id = ?',
        whereArgs: [budgetId],
      );
    } catch (e) {
      print('Error deleting shared budget: $e');
      rethrow;
    }
  }

  // Calculer le total des dépenses pour un budget partagé en ce mois
  Future<double> getMonthlyBudgetSpending(String budgetId) async {
    try {
      final members = await getBudgetMembers(budgetId);
      final memberIds = members.map((m) => m.userId).toList();

      if (memberIds.isEmpty) return 0.0;

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      final placeholders = List.filled(memberIds.length, '?').join(',');
      final result = await _db.db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total FROM transactions
        WHERE user_id IN ($placeholders)
        AND type = 'expense'
        AND date >= ?
        AND date <= ?
      ''', [...memberIds, firstDayOfMonth.toIso8601String(), lastDayOfMonth.toIso8601String()]);

      if (result.isEmpty) return 0.0;
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      print('Error calculating budget spending: $e');
      rethrow;
    }
  }

  // Vérifier si un budget est dépassé
  Future<bool> isBudgetExceeded(String budgetId) async {
    try {
      final budget = await getBudgetById(budgetId);
      if (budget == null) return false;

      final spending = await getMonthlyBudgetSpending(budgetId);
      return spending > budget.monthlyLimit;
    } catch (e) {
      print('Error checking budget exceeded: $e');
      rethrow;
    }
  }
}
