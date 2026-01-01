import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/categories_service.dart';

class CategoriesProvider extends ChangeNotifier {
  final CategoriesService _categoriesService = CategoriesService();
  
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserCategories(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _categoriesService.getUserCategories(userId);
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<List<CategoryModel>> getCategoriesByType(
    String userId,
    String type,
  ) async {
    try {
      return await _categoriesService.getUserCategoriesByType(userId, type);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<List<String>> getAvailableCategories(String userId, String type) async {
    try {
      return await _categoriesService.getAvailableCategories(userId, type);
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<void> createCategory({
    required String userId,
    required String name,
    required String type,
    String? color,
    String? icon,
  }) async {
    try {
      final newCategory = await _categoriesService.createCategory(
        userId: userId,
        name: name,
        type: type,
        color: color,
        icon: icon,
      );
      _categories.add(newCategory);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? color,
    String? icon,
  }) async {
    try {
      await _categoriesService.updateCategory(
        categoryId,
        name: name,
        color: color,
        icon: icon,
      );
      final index = _categories.indexWhere((c) => c.id == categoryId);
      if (index != -1) {
        final cat = _categories[index];
        _categories[index] = CategoryModel(
          id: cat.id,
          userId: cat.userId,
          name: name ?? cat.name,
          type: cat.type,
          color: color ?? cat.color,
          icon: icon ?? cat.icon,
          createdAt: cat.createdAt,
        );
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _categoriesService.deleteCategory(categoryId);
      _categories.removeWhere((c) => c.id == categoryId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
}
