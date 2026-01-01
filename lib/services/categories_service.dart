import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import 'db_service.dart';

class CategoriesService {
  final _db = DBService.instance;
  static const _uuid = Uuid();

  // Catégories par défaut
  static const defaultExpenseCategories = [
    'Alimentation',
    'Transport',
    'Logement',
    'Santé',
    'Divertissement',
    'Shopping',
    'Utilitaires',
    'Autre'
  ];

  static const defaultIncomeCategories = [
    'Salaire',
    'Freelance',
    'Investissements',
    'Autre'
  ];

  // Créer une catégorie personnalisée
  Future<CategoryModel> createCategory({
    required String userId,
    required String name,
    required String type,
    String? color,
    String? icon,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      await _db.db.insert('categories', {
        'id': id,
        'user_id': userId,
        'name': name,
        'type': type,
        'color': color,
        'icon': icon,
        'created_at': now.toIso8601String(),
      });

      return CategoryModel(
        id: id,
        userId: userId,
        name: name,
        type: type,
        color: color,
        icon: icon,
        createdAt: now,
      );
    } catch (e) {
      print('Error creating category: $e');
      rethrow;
    }
  }

  // Récupérer les catégories d'un utilisateur
  Future<List<CategoryModel>> getUserCategories(String userId) async {
    try {
      final maps = await _db.db.query(
        'categories',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at ASC',
      );

      return maps.map((m) => CategoryModel.fromMap(m)).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    }
  }

  // Récupérer les catégories d'un utilisateur par type (income/expense)
  Future<List<CategoryModel>> getUserCategoriesByType(
    String userId,
    String type,
  ) async {
    try {
      final maps = await _db.db.query(
        'categories',
        where: 'user_id = ? AND type = ?',
        whereArgs: [userId, type],
        orderBy: 'created_at ASC',
      );

      return maps.map((m) => CategoryModel.fromMap(m)).toList();
    } catch (e) {
      print('Error fetching categories by type: $e');
      rethrow;
    }
  }

  // Récupérer les catégories (personnalisées + défaut) pour un type
  Future<List<String>> getAvailableCategories(String userId, String type) async {
    try {
      final customCategories = await getUserCategoriesByType(userId, type);
      final customNames = customCategories.map((c) => c.name).toList();

      final defaultCategories =
          type == 'expense' ? defaultExpenseCategories : defaultIncomeCategories;

      return [...defaultCategories, ...customNames];
    } catch (e) {
      print('Error fetching available categories: $e');
      rethrow;
    }
  }

  // Mettre à jour une catégorie
  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? color,
    String? icon,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (color != null) updateData['color'] = color;
      if (icon != null) updateData['icon'] = icon;

      if (updateData.isNotEmpty) {
        await _db.db.update(
          'categories',
          updateData,
          where: 'id = ?',
          whereArgs: [categoryId],
        );
      }
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  // Supprimer une catégorie
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _db.db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }
}
