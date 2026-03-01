import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/transactions_service.dart';

class TransactionSearchService {
  TransactionSearchService._private();
  static final TransactionSearchService instance = TransactionSearchService._private();

  /// Search transactions by multiple criteria
  List<TransactionModel> search(
    List<TransactionModel> transactions, {
    String? query,
    String? category,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
  }) {
    var results = List<TransactionModel>.from(transactions);

    // Filter by search query (description)
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      results = results.where((tx) {
        return (tx.description?.toLowerCase().contains(lowerQuery) ?? false) ||
               (tx.category?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    // Filter by category
    if (category != null && category.isNotEmpty) {
      results = results.where((tx) => tx.category == category).toList();
    }

    // Filter by type (income/expense)
    if (type != null && type.isNotEmpty) {
      results = results.where((tx) => tx.type == type).toList();
    }

    // Filter by date range
    if (startDate != null) {
      results = results.where((tx) => tx.date.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      final endOfDay = endDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      results = results.where((tx) => tx.date.isBefore(endOfDay)).toList();
    }

    // Filter by amount range
    if (minAmount != null) {
      results = results.where((tx) => tx.amount >= minAmount).toList();
    }
    if (maxAmount != null) {
      results = results.where((tx) => tx.amount <= maxAmount).toList();
    }

    /// Sort by date, most recent first
    results.sort((a, b) => b.date.compareTo(a.date));

    return results;
  }

  /// Get unique categories from transactions
  List<String> getCategories(List<TransactionModel> transactions) {
    final categories = <String>{};
    for (var tx in transactions) {
      if (tx.category != null) {
        categories.add(tx.category!);
      }
    }
    return categories.toList()..sort();
  }

  /// Get transactions for a specific month
  List<TransactionModel> getByMonth(
    List<TransactionModel> transactions,
    int year,
    int month,
  ) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    
    return search(
      transactions,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get high-value transactions
  List<TransactionModel> getHighValueTransactions(
    List<TransactionModel> transactions, {
    double minAmount = 100,
  }) {
    return search(
      transactions,
      minAmount: minAmount,
    );
  }
}
